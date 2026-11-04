# Heartbeat — Testing Guide

This guide explains how to test the Elixir Heartbeat application, including multiple endpoint monitoring, HTTP responses, concurrent execution, and automatic Task restarts.

## 1. Prerequisites

- Elixir and Erlang/OTP installed
- Git installed
- Project dependencies installed
- Internet connection for testing public endpoints

## 2. Setup

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/heartbeat.git
cd heartbeat
```

Install dependencies:

```bash
mix deps.get
```

Compile the project:

```bash
mix compile
```

Start the application:

```bash
iex -S mix
```

**Expected:** All configured heartbeat workers start automatically.

## 3. Test 1 — Verify Multiple Workers

In IEx:

```elixir
Supervisor.which_children(Heartbeat.Supervisor)
```

Expected result (PIDs will vary):

```elixir
[
  {{:heartbeat, "GitHub"}, #PID<0.250.0>, :worker, [Heartbeat.Worker]},
  {{:heartbeat, "Google"}, #PID<0.251.0>, :worker, [Heartbeat.Worker]},
  {{:heartbeat, "My API"}, #PID<0.252.0>, :worker, [Heartbeat.Worker]}
]
```

**Pass criteria:**

- All three workers exist.
- Each worker has a unique PID.
- All workers are running independently.

## 4. Test 2 — Successful HTTP Response

Configure an endpoint:

```elixir
%{
  name: "Google",
  url: "https://www.google.com",
  interval: 10_000
}
```

Restart the application to load the updated configuration.

Expected logs:

```text
[info] Starting monitor: Google
[info] [Google] UP HTTP 200 (120ms)
```

**Pass criteria:**

- HTTP 2xx is reported as UP.
- Response time is logged.
- The worker repeats the request after the configured interval plus request duration.

## 5. Test 3 — HTTP 500 Error

Start a local HTTP test server in a separate terminal:

```bash
python3 -m http.server 8080
```

This server normally returns HTTP 200 for existing resources and HTTP 404 for missing resources.

To simulate HTTP 500, create `mock_server.py`:

```python
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(500)
        self.end_headers()
        self.wfile.write(b"Internal Server Error")

HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
```

Stop the earlier server before starting this one:

```bash
python3 mock_server.py
```

Configure Heartbeat:

```elixir
%{
  name: "Test API",
  url: "http://localhost:8080",
  interval: 5_000
}
```

Restart Heartbeat.

Expected logs:

```text
[warning] [Test API] DOWN HTTP 500
```

**Pass criteria:**

- HTTP 500 is reported as DOWN.
- The monitoring process remains alive.
- The next heartbeat check runs normally.
- The supervisor does not restart the process just because the HTTP request returned 500.

## 6. Test 4 — Connection Failure

Configure an endpoint where no server is listening:

```elixir
%{
  name: "Unavailable API",
  url: "http://127.0.0.1:59999",
  interval: 5_000
}
```

Expected logs:

```text
[error] [Unavailable API] ERROR ...
```

**Pass criteria:**

- Connection failure is handled.
- Worker does not crash.
- Monitoring continues.

## 7. Test 5 — Automatic Task Restart

This test verifies `restart: :permanent`.

Start the application and list workers:

```elixir
Supervisor.which_children(Heartbeat.Supervisor)
```

Find the Google worker:

```elixir
children = Supervisor.which_children(Heartbeat.Supervisor)

{{:heartbeat, "Google"}, pid, _, _} =
  Enum.find(children, fn {id, _, _, _} ->
    id == {:heartbeat, "Google"}
  end)
```

Check whether the process is alive:

```elixir
Process.alive?(pid)
```

Expected:

```elixir
true
```

Terminate the worker:

```elixir
Process.exit(pid, :kill)
```

Inspect workers again:

```elixir
Supervisor.which_children(Heartbeat.Supervisor)
```

**Pass criteria:**

- A new Google worker is started.
- The new PID differs from the original PID.
- Other endpoint workers retain their original PIDs.
- Google monitoring resumes automatically.

## 8. Test 6 — Verify Process Isolation

Capture the PIDs of all workers:

```elixir
before_restart =
  Supervisor.which_children(Heartbeat.Supervisor)
```

Terminate a single worker:

```elixir
{{:heartbeat, "Google"}, pid, _, _} =
  Enum.find(before_restart, fn {id, _, _, _} ->
    id == {:heartbeat, "Google"}
  end)

Process.exit(pid, :kill)
```

Capture PIDs again:

```elixir
after_restart =
  Supervisor.which_children(Heartbeat.Supervisor)
```

Compare:

```elixir
Enum.map(after_restart, fn {id, pid, _, _} ->
  {id, pid}
end)
```

**Pass criteria:**

- Only the terminated worker has a different PID.
- Other workers continue uninterrupted.
- The supervisor remains alive.

## 9. Test 7 — Verify Monitoring Intervals

Configure different intervals:

```elixir
[
  %{
    name: "API A",
    url: "https://www.google.com",
    interval: 5_000
  },
  %{
    name: "API B",
    url: "https://www.githubstatus.com/api/v2/status.json",
    interval: 10_000
  }
]
```

Observe the logs for at least 30 seconds.

**Pass criteria:**

- API A is checked