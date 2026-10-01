using NetPusula.Api.Auth;
using Microsoft.EntityFrameworkCore;
using NetPusula.Api;
using NetPusula.Infrastructure;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddNetPusulaAuthentication();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    if (origins.Any(origin => origin.Contains('*') || !Uri.TryCreate(origin, UriKind.Absolute, out var uri)
        || (uri.Scheme != "https" && uri.Scheme != "http") || uri.GetLeftPart(UriPartial.Authority) != origin))
        throw new InvalidOperationException("CORS origins must be explicit HTTP(S) origins without paths or trailing slashes.");
    if (origins.Length > 0)
        policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));

var app = builder.Build();
if (args.Contains("--check-database"))
{
    await using var scope = app.Services.CreateAsyncScope();
    try
    {
        var db = scope.ServiceProvider.GetRequiredService<NetPusulaDbContext>();
        var connected = await db.Database.CanConnectAsync();
        Console.WriteLine(connected ? "Database connection successful." : "Database connection failed.");
        Environment.ExitCode = connected ? 0 : 1;
    }
    catch
    {
        Console.Error.WriteLine("Database connection failed. Check configuration and database availability.");
        Environment.ExitCode = 1;
    }
    return;
}

app.UseExceptionHandler();
app.UseStatusCodePages(async status =>
{
    var context = status.HttpContext;
    if (context.Request.Path.StartsWithSegments("/api/auth") || context.Request.Path.StartsWithSegments("/api/user-exams"))
        await Results.Problem(statusCode: context.Response.StatusCode,
            title: "The authentication request could not be processed.").ExecuteAsync(context);
});
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseHsts();
    app.UseHttpsRedirection();
}
app.UseCors();
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/api/auth") || context.Request.Path.StartsWithSegments("/api/user-exams"))
    {
        context.Response.Headers.CacheControl = "no-store";
        context.Response.Headers.Pragma = "no-cache";
        if (!app.Environment.IsDevelopment() && !context.Request.IsHttps)
        {
            await Results.Problem(statusCode: 400, title: "HTTPS is required.").ExecuteAsync(context);
            return;
        }
        var bodySize = context.Features.Get<Microsoft.AspNetCore.Http.Features.IHttpMaxRequestBodySizeFeature>();
        if (bodySize is { IsReadOnly: false }) bodySize.MaxRequestBodySize = 16_384;
    }
    await next(context);
});
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapGet("/api/health", () => Results.Ok(new { status = "healthy" }));
app.MapExamEndpoints();
app.MapAuthEndpoints();
app.MapPreparationEndpoints();
app.Run();

public partial class Program { }
