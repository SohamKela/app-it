// Named Mutex + named pipe single-instance — the Windows reading of macOS warm
// relaunch (applicationShouldHandleReopen in wrapper.swift / ADR 0005 row 5).
//
// The first host for a slug owns the mutex and listens on the pipe. A second
// launch finds the mutex already held, connects to the pipe, says "show", and
// exits; the resident (tray-hidden) host re-shows its window with the dev
// server still warm in its Job Object — no reattach, no cold start.
//
// Keyed by slug so two different app-it apps can each be resident at once.
// Whether the re-show actually feels instant, steals focus correctly, and
// lands on the right monitor is deferred to a Windows maintainer (ADR 0005).

using System;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;

namespace AppItWindows;

public sealed class SingleInstanceGate : IDisposable
{
    private readonly string _pipeName;
    private readonly Mutex _mutex;
    private CancellationTokenSource? _cts;

    public bool IsPrimary { get; }
    public event Action? ReShowRequested;

    public SingleInstanceGate(string slug)
    {
        var key = $"app-it-{slug}";
        _pipeName = key + "-pipe";
        _mutex = new Mutex(initiallyOwned: true, name: key + "-mutex", out bool createdNew);
        IsPrimary = createdNew;
    }

    /// Called by a secondary launch: ping the resident host, then this process
    /// exits. Best-effort — if the resident is mid-shutdown the connect fails
    /// and there is simply nothing to re-show.
    public void SignalExistingInstance()
    {
        try
        {
            using var client = new NamedPipeClientStream(".", _pipeName, PipeDirection.Out);
            client.Connect(2000);
            using var writer = new StreamWriter(client) { AutoFlush = true };
            writer.WriteLine("show");
        }
        catch
        {
            // Resident may be exiting; nothing actionable.
        }
    }

    public void BeginListening()
    {
        _cts = new CancellationTokenSource();
        _ = ListenLoopAsync(_cts.Token);
    }

    private async Task ListenLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                using var server = new NamedPipeServerStream(
                    _pipeName, PipeDirection.In, maxNumberOfServerInstances: 1,
                    PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
                await server.WaitForConnectionAsync(ct);
                using var reader = new StreamReader(server);
                var message = await reader.ReadLineAsync(ct);
                if (message == "show") ReShowRequested?.Invoke();
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch
            {
                // A malformed/dropped connection shouldn't kill the listener.
            }
        }
    }

    public void Dispose()
    {
        _cts?.Cancel();
        if (IsPrimary)
        {
            try { _mutex.ReleaseMutex(); } catch { /* not owned / already released */ }
        }
        _mutex.Dispose();
    }
}
