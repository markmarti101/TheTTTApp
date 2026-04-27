/// Swallows the raw exception and returns a user-facing message.
/// Use everywhere a catch-block would otherwise expose $e to the UI.
String appError(Object _, String message) => message;
