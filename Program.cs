using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;

internal static class Program
{
    // 다중 선택 시 Explorer가 N번 실행해도 1번 처리로 합치기 위한 간단한 큐
    private const string MutexName = @"Local\NfcRenamer_Mutex_v1";
    private static readonly string AppDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NfcRenamer");
    private static readonly string QueueFile = Path.Combine(AppDir, "queue.txt");
    private static readonly string LogFile = Path.Combine(AppDir, "log.txt");

    [STAThread]
    private static int Main(string[] args)
    {
        Directory.CreateDirectory(AppDir);

        bool createdNew;
        using var mutex = new Mutex(initiallyOwned: true, name: MutexName, createdNew: out createdNew);

        try
        {
            // 어떤 인자로 실행됐든 큐에 적재
            EnqueueInvocation(args);

            if (!createdNew)
            {
                // 이미 다른 인스턴스가 처리 중(또는 곧 처리 예정)이므로 조용히 종료
                return 0;
            }

            // 첫 인스턴스가 짧게 대기하면서 다른 인스턴스가 큐에 적재할 시간을 줌
            Thread.Sleep(250);

            var jobs = DequeueAllJobsDistinct();
            if (jobs.Count == 0) return 0;

            foreach (var job in jobs)
            {
                try
                {
                    ProcessJob(job);
                }
                catch (Exception ex)
                {
                    Log($"[ERR] job={job.Mode} path={job.Path} ex={ex}");
                }
            }

            return 0;
        }
        catch (Exception ex)
        {
            Log($"[FATAL] ex={ex}");
            return 1;
        }
        finally
        {
            if (createdNew)
            {
                try { mutex.ReleaseMutex(); } catch { /* ignore */ }
            }
        }
    }

    private enum Mode { FileOrDir, RecursiveDir }

    private sealed record Job(Mode Mode, string Path);

    private static void EnqueueInvocation(string[] args)
    {
        // 인자 파싱: -r 있으면 Recursive
        bool recursive = args.Any(a => string.Equals(a, "-r", StringComparison.OrdinalIgnoreCase)
                                    || string.Equals(a, "/r", StringComparison.OrdinalIgnoreCase));

        var paths = args
            .Where(a => !string.Equals(a, "-r", StringComparison.OrdinalIgnoreCase)
                     && !string.Equals(a, "/r", StringComparison.OrdinalIgnoreCase))
            .Where(a => !string.IsNullOrWhiteSpace(a))
            .ToList();

        if (paths.Count == 0) return;

        foreach (var p in paths)
        {
            var mode = recursive ? Mode.RecursiveDir : Mode.FileOrDir;
            WriteQueueLine(mode, p);
        }
    }

    private static void WriteQueueLine(Mode mode, string path)
    {
        // 안전한 저장: mode|base64(path)
        var payload = Convert.ToBase64String(Encoding.UTF8.GetBytes(path));
        var line = $"{(mode == Mode.RecursiveDir ? "R" : "F")}|{payload}";

        // 파일 append 시 경합 방지(짧게 재시도)
        for (int i = 0; i < 20; i++)
        {
            try
            {
                using var fs = new FileStream(QueueFile, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
                fs.Seek(0, SeekOrigin.End);
                using var sw = new StreamWriter(fs, Encoding.UTF8, leaveOpen: true);
                sw.WriteLine(line);
                sw.Flush();
                return;
            }
            catch
            {
                Thread.Sleep(10);
            }
        }
    }

    private static List<Job> DequeueAllJobsDistinct()
    {
        if (!File.Exists(QueueFile)) return new List<Job>();

        string[] lines;
        // 큐 읽고 비우기
        using (var fs = new FileStream(QueueFile, FileMode.Open, FileAccess.ReadWrite, FileShare.None))
        using (var sr = new StreamReader(fs, Encoding.UTF8))
        {
            var content = sr.ReadToEnd();
            lines = content.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries);
            fs.SetLength(0);
        }

        var jobs = new List<Job>();
        foreach (var line in lines)
        {
            var parts = line.Split('|');
            if (parts.Length != 2) continue;

            var mode = parts[0] == "R" ? Mode.RecursiveDir : Mode.FileOrDir;

            string path;
            try
            {
                path = Encoding.UTF8.GetString(Convert.FromBase64String(parts[1]));
            }
            catch { continue; }

            if (string.IsNullOrWhiteSpace(path)) continue;
            jobs.Add(new Job(mode, path));
        }

        // 중복 제거(동일 모드+경로)
        return jobs
            .GroupBy(j => (j.Mode, NormalizePathForCompare(j.Path)))
            .Select(g => g.First())
            .ToList();
    }

    private static string NormalizePathForCompare(string p)
    {
        try { return Path.GetFullPath(p).TrimEnd(Path.DirectorySeparatorChar); }
        catch { return p; }
    }

    private static void ProcessJob(Job job)
    {
        var full = job.Path;
        if (!File.Exists(full) && !Directory.Exists(full))
        {
            Log($"[SKIP] not found: {full}");
            return;
        }

        if (job.Mode == Mode.RecursiveDir)
        {
            if (Directory.Exists(full))
                NormalizeDirectoryRecursive(full);
            else
                NormalizeSingle(full);
        }
        else
        {
            NormalizeSingle(full);
        }
    }

    private static void NormalizeDirectoryRecursive(string dir)
    {
        // 하위부터 처리(경로 길이 내림차순)
        var entries = Directory.EnumerateFileSystemEntries(dir, "*", SearchOption.AllDirectories)
            .OrderByDescending(p => p.Length)
            .ToList();

        foreach (var e in entries)
            NormalizeSingle(e);

        // 마지막에 루트 디렉터리 자신도 정규화
        NormalizeSingle(dir);
    }

    private static void NormalizeSingle(string fullPath)
    {
        bool isDir = Directory.Exists(fullPath);
        string name = isDir ? new DirectoryInfo(fullPath).Name : Path.GetFileName(fullPath);

        var normalized = name.Normalize(NormalizationForm.FormC); // NFC
        if (string.Equals(name, normalized, StringComparison.Ordinal))
            return;

        var parent = Path.GetDirectoryName(fullPath);
        if (string.IsNullOrWhiteSpace(parent))
        {
            // 드라이브 루트 같은 케이스
            Log($"[SKIP] no parent: {fullPath}");
            return;
        }

        var targetName = EnsureUniqueName(parent, normalized, isDir);
        var targetPath = Path.Combine(parent, targetName);

        if (isDir)
            Directory.Move(fullPath, targetPath);
        else
            File.Move(fullPath, targetPath);

        Log($"[OK] {(isDir ? "DIR" : "FILE")} {name} -> {targetName}");
    }

    private static string EnsureUniqueName(string parent, string desiredName, bool isDir)
    {
        string candidatePath = Path.Combine(parent, desiredName);
        if (!File.Exists(candidatePath) && !Directory.Exists(candidatePath))
            return desiredName;

        if (isDir)
        {
            for (int i = 1; i < 10000; i++)
            {
                var n = $"{desiredName} ({i})";
                var p = Path.Combine(parent, n);
                if (!Directory.Exists(p) && !File.Exists(p)) return n;
            }
        }
        else
        {
            var baseName = Path.GetFileNameWithoutExtension(desiredName);
            var ext = Path.GetExtension(desiredName);
            for (int i = 1; i < 10000; i++)
            {
                var n = $"{baseName} ({i}){ext}";
                var p = Path.Combine(parent, n);
                if (!File.Exists(p) && !Directory.Exists(p)) return n;
            }
        }

        throw new IOException("Too many name collisions: " + desiredName);
    }

    private static void Log(string msg)
    {
        try
        {
            File.AppendAllText(LogFile, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {msg}{Environment.NewLine}");
        }
        catch { /* ignore */ }
    }
}
