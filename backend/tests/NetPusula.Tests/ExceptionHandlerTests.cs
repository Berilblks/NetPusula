using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging.Abstractions;
using NetPusula.Api;

namespace NetPusula.Tests;

public sealed class ExceptionHandlerTests
{
    [Fact]
    public async Task Exception_response_does_not_expose_internal_details()
    {
        var context = new DefaultHttpContext();
        await using var body = new MemoryStream();
        context.Response.Body = body;
        var handler = new GlobalExceptionHandler(NullLogger<GlobalExceptionHandler>.Instance);
        var handled = await handler.TryHandleAsync(context, new InvalidOperationException("private connection details"), CancellationToken.None);
        Assert.True(handled);
        Assert.Equal(500, context.Response.StatusCode);
        body.Position = 0;
        using var json = await JsonDocument.ParseAsync(body);
        Assert.Equal("An unexpected error occurred.", json.RootElement.GetProperty("title").GetString());
        Assert.DoesNotContain("private connection details", json.RootElement.GetRawText());
        Assert.False(json.RootElement.TryGetProperty("stackTrace", out _));
    }
}
