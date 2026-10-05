using NetPusula.Application.Auth;
using NetPusula.Application.Statistics;
namespace NetPusula.Api;
public static class StatisticsEndpoints
{
    public static void MapStatisticsEndpoints(this WebApplication app)
    {
        app.MapGet("/api/statistics", async (HttpRequest request, ICurrentUser current, IStatisticsService service, CancellationToken ct) =>
        {
            if (current.UserId is not Guid user) return Results.Unauthorized();
            var range = request.Query["range"].ToString();
            if (!request.Query.ContainsKey("range")) range = "20";
            if (request.Query.Keys.Any(k => k != "range") || range is not ("5" or "10" or "20" or "all"))
                return Results.Problem(statusCode:400,title:"Use range 5, 10, 20 or all only.");
            var dto = await service.GetAsync(user,range,ct);
            return dto is null ? Results.Problem(statusCode:409,title:"Active preparation required.",
                extensions:new Dictionary<string,object?> { ["code"]="active_preparation_required" }) : Results.Ok(dto);
        }).RequireAuthorization().WithTags("Statistics");
    }
}
