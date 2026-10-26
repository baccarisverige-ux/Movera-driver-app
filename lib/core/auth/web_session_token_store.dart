import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/auth/web_session_token_store_io.dart'
    if (dart.library.js_interop) 'package:movera/core/auth/web_session_token_store_web.dart';

/// The browser token store, or null where there is no browser.
///
/// Web keeps the tokens in localStorage, so the driver stays signed in after
/// a reload and after the tab, the browser or the Home-screen app is fully
/// closed. Owner decision of 2026-10-26, as in the rider app: "Stay signed
/// in after fully closing the app, like Uber. Signing out still removes
/// everything."
///
/// The trade-off, accepted with that decision: anyone who later opens the
/// app in the same browser profile (a shared or borrowed computer, a family
/// tablet) is signed in as this driver until someone signs out. Earlier
/// builds used sessionStorage, which ends with the tab, to avoid exactly
/// that.
/// - Sign-out and session expiry call [TokenStore.clear], which removes
///   both keys from localStorage and from sessionStorage.
/// - Every tab of the app shares the one session, and a sign-out in one
///   tab removes it for all of them.
/// - Unlike a cookie it is never sent with requests, so it adds no CSRF
///   surface.
/// - Script injected into the page could read it, as before; the tokens
///   now outlive the page until sign-out or the session's own expiry,
///   rather than only until the tab closes.
/// - In a Safari tab (not the Home-screen app) Safari may delete a site's
///   localStorage after about a week without a visit; the driver then
///   signs in again.
/// A session saved in sessionStorage by an earlier build is moved over on
/// the first read (`BrowserTokenStore`), so the update signs nobody out.
TokenStore? webSessionTokenStore() => createWebSessionTokenStore();
