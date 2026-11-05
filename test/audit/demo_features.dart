/// Legacy auth is excluded from the canonical demo by default.
const legacyAuthEnabled = bool.fromEnvironment(
  'MOVERA_ENABLE_LEGACY_AUTH',
  defaultValue: false,
);
