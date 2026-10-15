# How state management and local storage work

## State management

I used Provider. There are two `ChangeNotifier` classes, both created once in `main.dart`.

**TaskProvider** is the important one. It holds:

- `_tasks`: the full list of tasks, which is the single source of truth
- `_filter`: All, Pending or Completed
- `_query`: the text in the search box
- `_sortAscending`: whether the list is sorted earliest first or latest first

**ThemeProvider** only stores whether the app is in light or dark mode.

### How the screen gets data

`TaskListScreen` uses `context.watch<TaskProvider>()`. Whenever the provider calls `notifyListeners()`, the screen rebuilds with the new data.

When a button is pressed (add, delete, toggle), I use `context.read<TaskProvider>()` instead. `read` only gets the object so I can call a method on it, and it doesn't cause a rebuild by itself.

### What gets shown

The list on screen comes from a getter called `visibleTasks`. It does three things in order:

1. Keeps only the tasks matching the selected filter
2. Keeps only the tasks whose title contains the search text (ignoring upper and lower case)
3. Sorts the result by due date, and if two tasks have the same date, the higher priority comes first

Because it's calculated every time from the full list, the filter and search always work together without extra code. The summary card (total, pending, completed) counts all tasks and ignores the filter and search.

### Example: ticking a task as done

1. The user taps the circle on a task card
2. The card calls `onToggle`, and the list screen calls `provider.toggleStatus(task)`
3. The provider first saves the changed task to the database through the repository
4. Only if that worked, it replaces the task in `_tasks` and calls `notifyListeners()`
5. The list, the summary and the filter counts all update on their own
6. If saving failed, nothing changes in memory, `error` is set and a snackbar is shown

I save to the database before changing the list in memory on purpose. That way the screen never shows something that isn't actually saved.

## Local storage

I used SQLite through the `sqflite` package. `SqliteTaskRepository` creates a database file called `tasks.db` the first time the app needs it. There is one table:

| Column       | Type                                | Notes                          |
|--------------|-------------------------------------|--------------------------------|
| id           | INTEGER, primary key, autoincrement |                                |
| title        | TEXT, not null                      |                                |
| description  | TEXT, not null                      |                                |
| due_date     | INTEGER, not null                   | milliseconds since epoch       |
| is_completed | INTEGER, not null                   | 0 for pending, 1 for completed |
| priority     | INTEGER, not null                   | 0 low, 1 medium, 2 high        |

SQLite has no boolean, date or enum type, so `Task.toMap()` and `Task.fromMap()` convert between the Dart object and a database row.

- **Add:** `db.insert` gives back the new id, and I copy it onto the Task
- **Edit and toggle:** `db.update` with `where: 'id = ?'`
- **Delete:** `db.delete` with `where: 'id = ?'`
- **App start:** `TaskProvider.load()` reads every row into `_tasks`. This is why the tasks are still there after closing and reopening the app

The queries use `whereArgs` instead of building SQL strings by hand.

## Why a repository?

`TaskProvider` only knows about the abstract `TaskRepository` (get all, insert, update, delete). Because of that, the unit tests use a small in-memory fake and never need a real database. If I wanted to switch to Hive later, only the repository class would change.

## Tests

The tests are in `test/task_provider_test.dart`. They cover:

- adding, editing, deleting and toggling tasks
- validation (empty title, empty description, past due date)
- filter, search, and both together
- sorting by due date in both directions
- the summary counts
- tasks still being there after a "restart" (a new provider using the same storage)
- storage failures not crashing anything