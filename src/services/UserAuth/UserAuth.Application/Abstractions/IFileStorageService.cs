namespace UserAuth.Application.Abstractions;

public interface IFileStorageService
{
    Task<string> SaveFileAsync(Stream fileStream, string fileName, string folder, CancellationToken ct = default);
    void DeleteFile(string filePath);
}
