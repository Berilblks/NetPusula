using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace NetPusula.Api;

public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext context, Exception exception, CancellationToken cancellationToken)
    {
        // Do not log exception messages that could contain input values or database/token details.
        logger.LogError("Unhandled request exception ({ExceptionType}).", exception.GetType().Name);
        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = StatusCodes.Status500InternalServerError,
            Title = "An unexpected error occurred."
        }, options: (System.Text.Json.JsonSerializerOptions?)null, contentType: "application/problem+json", cancellationToken: cancellationToken);
        return true;
    }
}


