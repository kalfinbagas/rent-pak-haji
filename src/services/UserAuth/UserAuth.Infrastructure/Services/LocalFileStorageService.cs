using Microsoft.Extensions.Configuration;
using UserAuth.Application.Abstractions;

namespace UserAuth.Infrastructure.Services;

public sealed class LocalFileStorageService : IFileStorageService
{
    private readonly string _basePath;

    public LocalFileStorageService(IConfiguration config)
    {
        _basePath = config["FileStorage:BasePath"] ?? "uploads";
    }

    public async Task<string> SaveFileAsync(
        Stream fileStream,
        string fileName,
        string folder,
        CancellationToken ct = default)
    {
        var extension = Path.GetExtension(fileName);
        var uniqueName = $"{Guid.NewGuid()}{extension}";

        var targetDir = Path.Combine(_basePath, folder);
        Directory.CreateDirectory(targetDir);

        var relativePath = Path.Combine(folder, uniqueName);
        var fullPath     = Path.Combine(_basePath, relativePath);

        await using var output = File.Create(fullPath);
        await fileStream.CopyToAsync(output, ct);

        return relativePath;
    }

    public void DeleteFile(string filePath)
    {
        var fullPath = Path.Combine(_basePath, filePath);
        if (File.Exists(fullPath))
            File.Delete(fullPath);
    }
}
