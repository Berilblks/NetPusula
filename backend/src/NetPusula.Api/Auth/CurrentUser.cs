using System.IdentityModel.Tokens.Jwt;
using NetPusula.Application.Auth;

namespace NetPusula.Api.Auth;

public sealed class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public Guid? UserId => accessor.HttpContext?.User.Identity?.IsAuthenticated == true
        && Guid.TryParse(accessor.HttpContext.User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id)
        && id != Guid.Empty ? id : null;
}

