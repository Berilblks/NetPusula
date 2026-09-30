using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using NetPusula.Application.Auth;

namespace NetPusula.Api.Auth;

public sealed class JwtTokenIssuer(IOptions<JwtOptions> options, TimeProvider clock) : IAccessTokenIssuer
{
    public AccessToken Issue(Guid userId)
    {
        var configuration = options.Value;
        var now = clock.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(configuration.AccessTokenMinutes);
        var jwt = new JwtSecurityToken(configuration.Issuer, configuration.Audience,
            [new Claim(JwtRegisteredClaimNames.Sub, userId.ToString()),
             new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())],
            now, expires,
            new SigningCredentials(new SymmetricSecurityKey(Convert.FromBase64String(configuration.SigningKey)),
                SecurityAlgorithms.HmacSha256));
        return new AccessToken(new JwtSecurityTokenHandler().WriteToken(jwt), expires);
    }
}

