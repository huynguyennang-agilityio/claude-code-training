/// Why a session ended without the user signing out.
enum SessionEndReason {
  /// The tokens are no longer valid (expired, revoked, or not stored).
  expired,

  /// The account signed in on another device, which replaced this session.
  replaced,
}
