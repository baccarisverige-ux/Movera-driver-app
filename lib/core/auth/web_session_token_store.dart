import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/auth/web_session_token_store_io.dart'
    if (dart.library.js_interop) 'package:movera/core/auth/web_session_token_store_web.dart';

/// The browser token store, or null where there is no browser.
///
/// Web keeps the tokens in this tab's sessionStorage so a reload keeps the
/// driver signed in. Why sessionStorage, as in the rider app:
/// - it is scoped to one tab and one origin and is gone when the tab closes,
///   so a later visitor on a shared computer does not inherit the session;
/// - unlike a cookie it is never sent with requests, so it adds no CSRF
///   surface;
/// - script injected into the page could read it, but such script could
///   already call the API with an in-memory token.
/// localStorage was rejected because it outlives the tab and is shared by
/// every tab. Sign-out and session expiry call [TokenStore.clear].
TokenStore? webSessionTokenStore() => createWebSessionTokenStore();
