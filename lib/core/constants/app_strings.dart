/// User-facing strings shared across the app.
///
/// Centralised so text is never duplicated as literals in widgets and can be
/// replaced by a localisation layer later.
abstract final class AppStrings {
  /// Application display name.
  static const String appName = 'Workspace';

  // Failure messages shown to users. Raw exceptions are never displayed.
  /// Shown when the network connection fails.
  static const String failureNetwork =
      'Unable to reach the server. Check your connection and try again.';

  /// Shown when the device is offline and no cached data exists.
  static const String failureOffline =
      "You're offline and there is no saved data to show yet.";

  /// Shown when a request takes too long.
  static const String failureTimeout =
      'The server took too long to respond. Please try again.';

  /// Shown when the session is invalid or expired.
  static const String failureAuthentication =
      'Your session has expired. Please sign in again.';

  /// Shown when the user may not perform an action.
  static const String failureForbidden =
      "You don't have permission to do that.";

  /// Shown when a resource does not exist.
  static const String failureNotFound =
      'We could not find what you were looking for.';

  /// Shown when submitted data is rejected.
  static const String failureValidation =
      'Some of the information you entered is not valid.';

  /// Shown on server-side errors.
  static const String failureServer =
      'Something went wrong on our side. Please try again later.';

  /// Shown when a response cannot be understood.
  static const String failureParsing =
      'We received an unexpected response from the server.';

  /// Shown when local storage fails.
  static const String failureCache =
      'We could not read or save data on this device.';

  /// Shown for anything unclassified.
  static const String failureUnknown =
      'Something unexpected happened. Please try again.';

  // Validation messages.
  /// A required field is empty.
  static const String requiredField = 'This field is required.';

  /// The email address is malformed.
  static const String invalidEmail = 'Enter a valid email address.';

  /// The password does not meet the rules.
  static const String weakPassword =
      'Use at least 8 characters with a letter and a number.';

  /// A value exceeds its maximum length.
  static const String tooLong = 'This is too long.';

  // Generic actions and labels.
  /// Retry action.
  static const String tryAgain = 'Try again';

  /// Cancel action.
  static const String cancel = 'Cancel';

  /// Confirm action.
  static const String confirm = 'Confirm';

  /// Accessibility label for loading indicators.
  static const String loading = 'Loading';

  /// Tooltip for showing a hidden password.
  static const String showPassword = 'Show password';

  /// Tooltip for hiding a visible password.
  static const String hidePassword = 'Hide password';

  /// Banner shown above data that comes from device storage.
  static const String staleData =
      'Showing saved data. Some information may be out of date.';

  /// Title of the unknown route page.
  static const String pageNotFoundTitle = 'Page not found';

  /// Body of the unknown route page.
  static const String pageNotFoundMessage =
      'The page you are looking for does not exist.';

  /// Action leading back to the start of the app.
  static const String goHome = 'Go to start';

  // Navigation destinations.
  /// Dashboard destination.
  static const String navDashboard = 'Dashboard';

  /// Projects destination.
  static const String navProjects = 'Projects';

  /// Tasks destination.
  static const String navTasks = 'Tasks';

  /// Profile destination.
  static const String navProfile = 'Profile';

  // Authentication screens.
  /// Heading of the sign in screen.
  static const String signInTitle = 'Welcome back';

  /// Sub heading of the sign in screen.
  static const String signInSubtitle = 'Sign in to your workspace';

  /// Heading of the registration screen.
  static const String registerTitle = 'Create your account';

  /// Sub heading of the registration screen.
  static const String registerSubtitle = 'Start managing your projects';

  /// Name field label.
  static const String nameLabel = 'Full name';

  /// Email field label.
  static const String emailLabel = 'Email';

  /// Password field label.
  static const String passwordLabel = 'Password';

  /// Confirm password field label.
  static const String confirmPasswordLabel = 'Confirm password';

  /// Sign in button.
  static const String signIn = 'Sign in';

  /// Registration button.
  static const String createAccount = 'Create account';

  /// Link from sign in to registration.
  static const String goToRegister = "Don't have an account? Create one";

  /// Link from registration to sign in.
  static const String goToSignIn = 'Already have an account? Sign in';

  /// Shown when the two password fields differ.
  static const String passwordsDoNotMatch = 'The passwords do not match.';

  // Offline behaviour.
  /// Shown when a task that only exists on this device is edited or deleted.
  static const String taskPendingSync =
      'This task is still waiting to sync. Try again once it has synced.';

  // Tasks.
  /// Tasks list heading.
  static const String tasksTitle = 'Tasks';

  /// Search box hint on the task list.
  static const String searchTasks = 'Search tasks';

  /// Filters button.
  static const String filters = 'Filters';

  /// Sort section heading.
  static const String sortBy = 'Sort by';

  /// Apply filters button.
  static const String apply = 'Apply';

  /// Reset filters button.
  static const String reset = 'Reset';

  /// Clear filters action.
  static const String clearFilters = 'Clear filters';

  /// Empty task list heading.
  static const String noTasksTitle = 'No tasks yet';

  /// Empty task list text.
  static const String noTasksMessage = 'Create your first task to get started.';

  /// Heading when filters hide every task.
  static const String noMatchingTasksTitle = 'No matching tasks';

  /// Text when filters hide every task.
  static const String noMatchingTasksMessage =
      'Try changing your search or filters.';

  /// Create task action.
  static const String newTask = 'New task';

  /// Heading of the edit form.
  static const String editTaskTitle = 'Edit task';

  /// Save button of the edit form.
  static const String saveChanges = 'Save changes';

  /// Title field label.
  static const String taskTitleLabel = 'Title';

  /// Description field label.
  static const String descriptionLabel = 'Description';

  /// Project field label.
  static const String projectLabel = 'Project';

  /// Assignee field label.
  static const String assigneeLabel = 'Assignee';

  /// Option meaning nobody is assigned.
  static const String unassigned = 'Unassigned';

  /// Priority field label.
  static const String priorityLabel = 'Priority';

  /// Status field label.
  static const String statusLabel = 'Status';

  /// Due date field label.
  static const String dueDateLabel = 'Due date';

  /// Shown when a task has no deadline.
  static const String noDueDate = 'No due date';

  /// Pick a deadline.
  static const String setDueDate = 'Set due date';

  /// Remove the deadline.
  static const String clearDueDate = 'Clear due date';

  /// Task detail heading.
  static const String taskDetailTitle = 'Task';

  /// Attachments section heading.
  static const String attachments = 'Attachments';

  /// Activity section heading.
  static const String activity = 'Activity';

  /// Shown when a task has no attachments.
  static const String noAttachments = 'No attachments';

  /// Shown when a task has no activity.
  static const String noActivity = 'No activity yet';

  /// Edit action.
  static const String edit = 'Edit';

  /// Delete action.
  static const String delete = 'Delete';

  /// Delete confirmation heading.
  static const String deleteTaskTitle = 'Delete task?';

  /// Delete confirmation text.
  static const String deleteTaskMessage =
      'This task will be removed. This cannot be undone.';

  /// Snackbar after creating a task online.
  static const String taskCreated = 'Task created';

  /// Snackbar after creating a task offline.
  static const String taskSavedOffline =
      'Saved on this device. It will sync when you are back online.';

  /// Snackbar after updating a task.
  static const String taskUpdated = 'Task updated';

  /// Snackbar after deleting a task.
  static const String taskDeleted = 'Task deleted';

  /// Badge for tasks not yet confirmed by the server.
  static const String waitingToSync = 'Waiting to sync';

  /// Badge for tasks the server rejected.
  static const String notSaved = 'Not saved';

  /// Explanation for tasks the server rejected.
  static const String changeRejected =
      'The server rejected this change. Discard it to see the latest version.';

  /// Discard rejected changes action.
  static const String discardChanges = 'Discard changes';

  /// Overdue label.
  static const String overdue = 'Overdue';

  /// Option in the status filter and form.
  static const String statusTodo = 'To do';

  /// Option in the status filter and form.
  static const String statusInProgress = 'In progress';

  /// Option in the status filter and form.
  static const String statusDone = 'Done';

  /// Priority option.
  static const String priorityLow = 'Low';

  /// Priority option.
  static const String priorityMedium = 'Medium';

  /// Priority option.
  static const String priorityHigh = 'High';

  /// Priority option.
  static const String priorityUrgent = 'Urgent';

  /// Sort option.
  static const String sortDueSoonest = 'Due date (soonest)';

  /// Sort option.
  static const String sortDueLatest = 'Due date (latest)';

  /// Sort option.
  static const String sortPriority = 'Highest priority';

  /// Sort option.
  static const String sortRecent = 'Recently updated';

  // Projects.
  /// Projects list heading.
  static const String projectsTitle = 'Projects';

  /// Search box hint on the project list.
  static const String searchProjects = 'Search projects';

  /// Empty project list heading.
  static const String noProjectsTitle = 'No projects yet';

  /// Empty project list text.
  static const String noProjectsMessage = 'Projects will appear here.';

  /// Heading when search hides every project.
  static const String noMatchingProjectsTitle = 'No matching projects';

  /// Project detail heading.
  static const String projectDetailTitle = 'Project';

  /// Project tasks section heading.
  static const String projectTasks = 'Tasks in this project';

  /// Shown when a project has no tasks.
  static const String projectHasNoTasks = 'This project has no tasks yet.';

  /// Link to the full task list of a project.
  static const String viewAllTasks = 'View all tasks';

  /// Project status label.
  static const String projectActive = 'Active';

  /// Project status label.
  static const String projectOnHold = 'On hold';

  /// Project status label.
  static const String projectCompleted = 'Completed';

  /// Describes a count of tasks.
  static String taskCount(int count) => count == 1 ? '1 task' : '$count tasks';

  /// Describes a count of overdue tasks.
  static String overdueCount(int count) => '$count overdue';

  /// Describes changes waiting to be sent.
  static String pendingChanges(int count) => count == 1
      ? '1 change waiting to sync'
      : '$count changes waiting to sync';

  /// Describes the due date of a task.
  static String dueOn(String date) => 'Due $date';

  /// Describes how much of a project is finished.
  static String percentComplete(int percent) => '$percent% complete';

  // Dashboard.
  /// Dashboard heading.
  static const String dashboardTitle = 'Dashboard';

  /// Quick actions heading.
  static const String quickActions = 'Quick actions';

  /// Pending tasks heading.
  static const String pendingTasks = 'Pending tasks';

  /// Recently completed tasks heading.
  static const String completedTasks = 'Recently completed';

  /// Recent activity heading.
  static const String recentActivity = 'Recent activity';

  /// Label of the open task count.
  static const String openTasks = 'Open tasks';

  /// Label of the completed task count.
  static const String completedLabel = 'Completed';

  /// Label of the overdue task count.
  static const String overdueLabel = 'Overdue';

  /// Label of the project count.
  static const String projectsLabel = 'Projects';

  /// Shown when no tasks are waiting.
  static const String noPendingTasks = 'Nothing is waiting. Nice work.';

  /// Shown when no tasks were completed yet.
  static const String noCompletedTasks = 'No completed tasks yet.';

  /// Shown when there is no activity.
  static const String noRecentActivity = 'No recent activity.';

  /// Opens the full task list.
  static const String allTasks = 'All tasks';

  /// Greeting on the dashboard.
  static String greeting(String name) => 'Hi, $name';

  // Profile.
  /// Profile heading.
  static const String profileTitle = 'Profile';

  /// Phone field label.
  static const String phoneLabel = 'Phone';

  /// Role label.
  static const String roleLabel = 'Role';

  /// Role name.
  static const String roleAdmin = 'Administrator';

  /// Role name.
  static const String roleManager = 'Manager';

  /// Role name.
  static const String roleMember = 'Member';

  /// Appearance section heading.
  static const String appearance = 'Appearance';

  /// Theme option.
  static const String themeSystem = 'System';

  /// Theme option.
  static const String themeLight = 'Light';

  /// Theme option.
  static const String themeDark = 'Dark';

  /// Sign out action.
  static const String signOut = 'Sign out';

  /// Sign out confirmation heading.
  static const String signOutTitle = 'Sign out?';

  /// Sign out confirmation text.
  static const String signOutMessage =
      'You will need to sign in again to use the app.';

  /// Snackbar after saving the profile.
  static const String profileUpdated = 'Profile updated';

  /// Sign out confirmation text when changes are waiting to sync.
  static String signOutWithPending(int count) =>
      '${pendingChanges(count)}. The app will try to send them first.';

  /// Sends changes made offline now.
  static const String syncNow = 'Sync now';
}
