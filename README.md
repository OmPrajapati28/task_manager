# Task Manager

A simple task manager app I built in Flutter for the Anques Technolabs practical assignment. You can add tasks, edit them, tick them off, search, filter, and everything is saved on the phone so nothing disappears when the app is closed.

## What it does

- Shows all tasks with title, description, due date and status
- Completed tasks are struck through and faded, and overdue ones show in red
- Add and edit tasks through one form, with validation messages
- Mark a task completed or pending with the round check button
- Delete a task (asks for confirmation first)
- Filter by All / Pending / Completed and search by title. Both work at the same time
- Tasks are stored in SQLite so they're still there after restarting the app
- Empty states for "no tasks yet" and "nothing matches your search"

For the additional challenge I did all four options: task priority (Low / Medium / High), sorting by due date, dark mode, and a summary card showing total, pending and completed.

## Getting started

You need Flutter 3.27 or newer and an Android emulator or a phone with USB debugging on.

```bash
git clone https://github.com/OmPrajapati28/task_manager.git
cd task_manager
flutter pub get
flutter run
```

Run the unit tests:

```bash
flutter test
```

Build the APK:

```bash
flutter build apk --release
```

The APK ends up in `build/app/outputs/flutter-apk/app-release.apk`.

## Folder structure

```
lib/
  main.dart                       app start, providers, light and dark theme
  models/task.dart                Task class, enums, validation rules
  data/task_repository.dart       storage interface + SQLite version
  providers/task_provider.dart    all the task logic
  providers/theme_provider.dart   dark mode switch
  screens/
    task_list_screen.dart         main screen
    task_form_screen.dart         add / edit screen
  widgets/
    task_card.dart
    summary_bar.dart
    empty_state.dart
test/
  task_provider_test.dart
docs/
  STATE_AND_STORAGE.md
  AI_TOOLS_USED.md
```

## Architecture decisions

**Provider for state management.** The assignment allowed GetX, Provider or BLoC. I picked Provider because I already use it at work, and it's enough for an app this size. BLoC would have meant a lot of extra files for no real benefit here.

**Three layers.** The screens only show data and call methods. `TaskProvider` holds the logic. `TaskRepository` talks to the database. A screen never touches SQLite directly, which keeps the screens small and easy to read.

**Repository interface.** The provider depends on an abstract `TaskRepository`, not on SQLite itself. In the tests I swap in an in-memory version, so the tests run in a second without an emulator.

**One place for validation.** The rules (title required, minimum 3 characters, description required, due date can't be in the past for new tasks) live in `TaskValidators`. The form uses them for the error messages, and the provider checks them again before saving, so bad data can't get in even if the UI is bypassed.

**Filter, search and sort are calculated, not stored.** There is one list of tasks and a `visibleTasks` getter works out what to show from the current filter, search text and sort direction. That way they can't get out of sync with each other.

**Errors don't crash the app.** Every database call is wrapped. If one fails, the old state stays as it was and the user sees a snackbar.

**Dates** are saved as a number (milliseconds since epoch), date only, no time.

## Packages used

| Package       | Why                                     |
|---------------|-----------------------------------------|
| provider      | state management                        |
| sqflite       | SQLite database on the device           |
| path          | building the path for the database file |
| flutter_test  | unit tests (dev)                        |
| flutter_lints | lint rules (dev)                        |

## More documentation

- [How state management and storage work](docs/STATE_AND_STORAGE.md)
- [AI tools used](docs/AI_TOOLS_USED.md)

## Known limitations

- The dark mode choice is not saved, so the app opens in light mode every time.
- There is no time of day on a task, only a date.
- No notifications or reminders.