using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using NetPusula.Application.Auth;
using NetPusula.Domain;
using NetPusula.Infrastructure.Auth;

namespace NetPusula.Api.Auth;

public static class AuthSetup
{
    public static IServiceCollection AddNetPusulaAuthentication(this IServiceCollection services)
    {
        services.AddSingleton(TimeProvider.System);
        services.Configure<Microsoft.AspNetCore.Routing.RouteHandlerOptions>(x => x.ThrowOnBadRequest = false);
        services.AddOptions<JwtOptions>().BindConfiguration("Jwt")
            .Validate(x => x.IsValid(), "Configure Jwt issuer/audience, a Base64 signing key of 32-128 random bytes and a 1-60 minute lifetime.")
            .ValidateOnStart();
        services.AddOptions<AuthSessionOptions>().BindConfiguration("Auth")
            .Validate(x => x.RefreshTokenDays is >= 1 and <= 90, "RefreshTokenDays must be between 1 and 90.")
            .ValidateOnStart();
        services.AddOptions<AuthRateLimitOptions>().BindConfiguration("AuthRateLimit")
            .Validate(x => x.PermitLimit is >= 1 and <= 1000 && x.WindowSeconds is >= 1 and <= 3600,
                "Invalid authentication rate limits.").ValidateOnStart();
        services.Configure<PasswordHasherOptions>(x =>
        {
            x.CompatibilityMode = PasswordHasherCompatibilityMode.IdentityV3;
            x.IterationCount = 210_000;
        });
        services.AddSingleton<IPasswordHasher<User>, PasswordHasher<User>>();
        services.AddSingleton<PasswordTimingHash>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddSingleton<IAccessTokenIssuer, JwtTokenIssuer>();
        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>>((bearer, configured) =>
            {
                var jwt = configured.Value;
                bearer.MapInboundClaims = false;
                bearer.SaveToken = false;
                bearer.IncludeErrorDetails = false;
                bearer.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = jwt.Issuer,
                    ValidateAudience = true,
                    ValidAudience = jwt.Audience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Convert.FromBase64String(jwt.SigningKey)),
                    RequireSignedTokens = true,
                    ValidateLifetime = true,
                    RequireExpirationTime = true,
                    ClockSkew = TimeSpan.Zero,
                    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
                    ValidTypes = ["JWT"]
                };
                bearer.Events = new JwtBearerEvents
                {
                    OnTokenValidated = context =>
                    {
                        if (!Guid.TryParse(context.Principal?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id)
                            || id == Guid.Empty)
                            context.Fail("Invalid subject.");
                        return Task.CompletedTask;
                    },
                    OnChallenge = async context =>
                    {
                        context.HandleResponse();
                        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                        context.Response.Headers.WWWAuthenticate = "Bearer";
                        await context.Response.WriteAsJsonAsync(new ProblemDetails
                        {
                            Status = 401,
                            Title = "Authentication required."
                        }, options: (System.Text.Json.JsonSerializerOptions?)null, contentType: "application/problem+json", cancellationToken: context.HttpContext.RequestAborted);
                    },
                    OnForbidden = async context =>
                    {
                        context.Response.StatusCode = StatusCodes.Status403Forbidden;
                        await context.Response.WriteAsJsonAsync(new ProblemDetails
                        {
                            Status = 403,
                            Title = "Access denied."
                        }, options: (System.Text.Json.JsonSerializerOptions?)null, contentType: "application/problem+json", cancellationToken: context.HttpContext.RequestAborted);
                    }
                };
            });
        services.AddAuthorization();
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            options.AddPolicy("auth", context =>
            {
                var settings = context.RequestServices.GetRequiredService<IOptions<AuthRateLimitOptions>>().Value;
                // Socket peer only: never use arbitrary X-Forwarded-For values.
                return RateLimitPartition.GetFixedWindowLimiter(
                    context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = settings.PermitLimit,
                        Window = TimeSpan.FromSeconds(settings.WindowSeconds),
                        QueueLimit = 0,
                        AutoReplenishment = true
                    });
            });
            options.OnRejected = async (context, cancellationToken) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retry))
                    context.HttpContext.Response.Headers.RetryAfter =
                        Math.Ceiling(retry.TotalSeconds).ToString(CultureInfo.InvariantCulture);
                await context.HttpContext.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Status = 429,
                    Title = "Too many authentication attempts. Try again later."
                }, options: (System.Text.Json.JsonSerializerOptions?)null, contentType: "application/problem+json", cancellationToken: cancellationToken);
            };
        });
        return services;
    }
}



