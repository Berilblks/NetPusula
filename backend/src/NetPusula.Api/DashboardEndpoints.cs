using NetPusula.Application.Auth;
using NetPusula.Application.Dashboard;
namespace NetPusula.Api;
public static class DashboardEndpoints
{
    public static void MapDashboardEndpoints(this WebApplication app)
    {
        app.MapGet("/api/dashboard", async (ICurrentUser current, IDashboardService service, CancellationToken ct) =>
        {
            if (current.UserId is not Guid user) return Results.Unauthorized();
            var dto = await service.GetAsync(user,ct);
            return dto is null ? Results.Problem(statusCode:409,title:"Active preparation required.",
                extensions:new Dictionary<string,object?> { ["code"]="active_preparation_required" }) : Results.Ok(dto);
        }).RequireAuthorization().WithTags("Dashboard");
    }
}
