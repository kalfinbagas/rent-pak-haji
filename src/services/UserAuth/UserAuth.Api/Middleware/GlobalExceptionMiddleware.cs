using System.Net;
using System.Text.Json;

namespace UserAuth.Api.Middleware;

/// <summary>
/// Catches any unhandled exception and returns a consistent 500 JSON error envelope.
/// </summary>
public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next   = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception on {Method} {Path}: {Message}",
                context.Request.Method, context.Request.Path, ex.Message);

            await WriteErrorResponseAsync(context, ex);
        }
    }

    private static async Task WriteErrorResponseAsync(HttpContext context, Exception ex)
    {
        context.Response.StatusCode  = (int)HttpStatusCode.InternalServerError;
        context.Response.ContentType = "application/json";

        var body = JsonSerializer.Serialize(new
        {
            status    = "ERROR",
            message   = "Terjadi kesalahan internal. Mohon coba lagi atau hubungi support.",
            errorCode = "INTERNAL_SERVER_ERROR"
        });

        await context.Response.WriteAsync(body);
    }
}

public static class GlobalExceptionMiddlewareExtensions
{
    public static IApplicationBuilder UseGlobalExceptionHandler(this IApplicationBuilder app)
        => app.UseMiddleware<GlobalExceptionMiddleware>();
}
