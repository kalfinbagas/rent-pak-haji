using System.Net;
using System.Text.Json;

namespace BookingOrder.Api.Middleware;

/// <summary>
/// Validates that every non-exempt request carries an <c>X-Transaction-Id</c> header.
///
/// Exempt paths: /swagger, /health, and the root path.
///
/// If the header is missing or empty the request is rejected with 400 Bad Request
/// before it reaches any controller — keeping the API contract strict.
///
/// Inspired by SERA's RequestHeader middleware.
/// </summary>
public sealed class TransactionIdMiddleware
{
    private const string HeaderName = "X-Transaction-Id";

    private static readonly string[] ExemptPaths =
    [
        "/swagger",
        "/health",
        "/"
    ];

    private readonly RequestDelegate _next;

    public TransactionIdMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value ?? string.Empty;

        bool isExempt = ExemptPaths.Any(p =>
            path.StartsWith(p, StringComparison.OrdinalIgnoreCase));

        if (!isExempt)
        {
            if (!context.Request.Headers.TryGetValue(HeaderName, out var values) ||
                string.IsNullOrWhiteSpace(values.FirstOrDefault()))
            {
                await RejectAsync(context,
                    "Header X-Transaction-Id wajib disertakan pada setiap permintaan.");
                return;
            }
        }

        await _next(context);
    }

    private static async Task RejectAsync(HttpContext context, string message)
    {
        context.Response.StatusCode  = (int)HttpStatusCode.BadRequest;
        context.Response.ContentType = "application/json";

        var body = JsonSerializer.Serialize(new
        {
            status    = "BAD_REQUEST",
            message,
            errorCode = "MISSING_TRANSACTION_ID"
        });

        await context.Response.WriteAsync(body);
    }
}

public static class TransactionIdMiddlewareExtensions
{
    public static IApplicationBuilder UseTransactionIdValidation(this IApplicationBuilder app)
        => app.UseMiddleware<TransactionIdMiddleware>();
}
