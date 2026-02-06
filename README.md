# Mac Task Scheduler

A native macOS application that replicates Windows Task Scheduler functionality, allowing users to create, view, edit, and manage scheduled tasks using both launchd and cron backends.

## Features

### Task Management
- Create, edit, and delete scheduled tasks
- Enable/disable tasks without removing them
- Run tasks immediately (manual trigger)
- Import existing launchd and cron tasks

### Trigger Types

#### launchd Backend (Recommended)
- **Calendar**: Run on specific dates/times or recurring schedules
- **Interval**: Run every N seconds/minutes/hours/days
- **At Login**: Run when user logs in
- **At Startup**: Run when system boots
- **On Demand**: Manual trigger only

#### cron Backend
- Standard cron expressions
- Visual schedule builder

### Task Actions
- Run executables and applications
- Run shell scripts (inline or from file)
- Run AppleScript (inline or from file)

### Execution History
- Track all task executions
- View stdout/stderr output
- Success/failure status with exit codes
- Execution duration

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ for building

## Installation

1. Clone the repository
2. Open `Mac Task Scheduler.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Usage

### Creating a Task

1. Click the **+** button or press **Cmd+N**
2. Enter a task name and optional description
3. Choose a backend (launchd recommended)
4. Configure the action:
   - Select action type (Executable, Shell Script, or AppleScript)
   - Provide the path or script content
   - Add arguments if needed
5. Configure the trigger:
   - Select when the task should run
   - Set schedule details
6. Click **Save**

### Managing Tasks

- **Enable/Disable**: Click the toggle or use the context menu
- **Run Now**: Click the play button to run immediately
- **Edit**: Double-click or select Edit from context menu
- **Delete**: Use the context menu or toolbar button

### Discovering Existing Tasks

Click **Discover Tasks** to import existing launchd plists and cron entries that were created by Mac Task Scheduler.

## Data Storage

- **Task metadata**: `~/Library/Application Support/Mac Task Scheduler/tasks.json`
- **Execution history**: `~/Library/Application Support/Mac Task Scheduler/history.json`
- **launchd plists**: `~/Library/LaunchAgents/com.macscheduler.task.*.plist`
- **cron entries**: User crontab with `# Mac Task Scheduler:<uuid>` tags

## Architecture

```
Mac Task Scheduler/
├── App/                    # App entry point
├── Models/                 # Data models
│   ├── ScheduledTask       # Core task model
│   ├── TaskTrigger         # Trigger configuration
│   ├── TaskAction          # Action configuration
│   └── TaskStatus          # Execution status
├── Services/               # Backend services
│   ├── SchedulerService    # Protocol for backends
│   ├── LaunchdService      # launchd integration
│   ├── CronService         # cron integration
│   └── TaskHistoryService  # History tracking
├── Views/                  # SwiftUI views
├── ViewModels/             # View state management
└── Utilities/              # Helper utilities
```

## License

MIT License
