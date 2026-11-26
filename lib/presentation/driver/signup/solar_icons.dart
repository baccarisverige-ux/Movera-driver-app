import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Owner 2026-11-26 "Make solar icons" (sign-up v2 screens only): Solar
/// icon set, Linear style, by 480 Design
/// (https://www.figma.com/community/file/1166831539721848736), licence
/// CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/), taken from
/// the npm package @iconify-json/solar 1.2.17. Unchanged paths; the colour
/// is set when drawn. Credit also in docs/DEPENDENCIES.md.
enum Solar {
  back,
  forward,
  down,
  close,
  checklist,
  user,
  briefcase,
  document,
  add,
  scanner,
  gallery,
  folder,
  check,
  checkPlain,
  lock,
  camera,
  pin,
  pdf,
  danger,
  circle,
}

const String _movInk = '#12201C';

/// One Solar Linear icon, [size] square, Movera ink unless [color].
class SolarIcon extends StatelessWidget {
  const SolarIcon(this.icon, {super.key, this.size = 24, this.color});

  final Solar icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color;
    final hex = c == null
        ? _movInk
        : '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    // Keeps its own size inside a fixed box (a tight parent would stretch it).
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.string(
        _solarSvg[icon]!.replaceAll('currentColor', hex),
        width: size,
        height: size,
        excludeFromSemantics: true,
      ),
    );
  }
}

const Map<Solar, String> _solarSvg = {
  Solar.back:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 5L9 12L15 19"/></svg>',
  Solar.forward:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5L15 12L9 19"/></svg>',
  Solar.down:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 9L12 15L5 9"/></svg>',
  Solar.close:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M14.5 9.50002L12 12M12 12L9.5 14.5M12 12L9.49998 9.5M12 12L14.5 14.5"/></g></svg>',
  Solar.checklist:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path stroke-linejoin="round" d="M2 5.5L3.21429 7L7.5 3"/><path stroke-linejoin="round" d="M2 12.5L3.21429 14L7.5 10"/><path stroke-linejoin="round" d="M2 19.5L3.21429 21L7.5 17"/><path d="M22 19L12 19"/><path d="M22 12L12 12"/><path d="M22 5L12 5"/></g></svg>',
  Solar.user:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><circle cx="12" cy="6" r="4"/><path d="M20 17.5C20 19.9853 20 22 12 22C4 22 4 19.9853 4 17.5C4 15.0147 7.58172 13 12 13C16.4183 13 20 15.0147 20 17.5Z"/></g></svg>',
  Solar.briefcase:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M21 12.2986C20.9991 15.9744 20.9652 19.6878 19.682 20.8284C18.3639 22 16.2426 22 12 22C7.75734 22 5.63601 22 4.318 20.8284C3.03474 19.6878 3.00089 15.9744 3 12.2986"/><path d="M6.5 5C7.32344 4.97913 8.15925 4.45491 8.43944 3.68032C8.44806 3.65649 8.4569 3.62999 8.47457 3.57697L8.50023 3.5C8.54241 3.37344 8.56351 3.31014 8.58608 3.254C8.87427 2.53712 9.54961 2.05037 10.3208 2.00366C10.3812 2 10.4479 2 10.5814 2H13.4191C13.5525 2 13.6192 2 13.6796 2.00366C14.4508 2.05037 15.1262 2.53712 15.4144 3.254C15.4369 3.31014 15.458 3.37343 15.5002 3.5L15.5259 3.57697C15.5435 3.62968 15.5524 3.65656 15.561 3.68032C15.8412 4.45491 16.6766 4.97913 17.5 5"/><path d="M10 12.5H14C14.2761 12.5 14.5 12.7239 14.5 13V15.1615C14.5 15.3659 14.3755 15.5498 14.1857 15.6257L13.4856 15.9058C12.5319 16.2872 11.4681 16.2872 10.5144 15.9058L9.8143 15.6257C9.62448 15.5498 9.5 15.3659 9.5 15.1615V13C9.5 12.7239 9.72386 12.5 10 12.5Z"/><path d="M14.5 14.2501L20.6677 12.3998C21.2632 12.2211 21.5609 12.1317 21.7498 11.9176C21.7866 11.8759 21.8199 11.8312 21.8492 11.784C22 11.5415 22 11.2307 22 10.6089C22 8.15877 22 6.9337 21.327 6.10659C21.1977 5.94763 21.0524 5.80233 20.8934 5.67298C20.0663 5 18.8412 5 16.3911 5H7.60893C5.15877 5 3.9337 5 3.10659 5.67298C2.94763 5.80233 2.80233 5.94763 2.67298 6.10659C2 6.9337 2 8.15877 2 10.6089C2 11.2307 2 11.5415 2.15078 11.784C2.18015 11.8312 2.21341 11.8759 2.25021 11.9176C2.43915 12.1317 2.7369 12.2211 3.3324 12.3997L9.49988 14.25"/></g></svg>',
  Solar.document:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M11 22H13C16.7712 22 18.6569 22 19.8284 20.8284C21 19.6569 21 17.7712 21 14V10C21 6.22876 21 4.34315 19.8284 3.17157C18.6569 2 16.7712 2 13 2H11C7.22876 2 5.34315 2 4.17157 3.17157C3 4.34315 3 6.22876 3 10V14C3 17.7712 3 19.6569 4.17157 20.8284C5.34315 22 7.22876 22 11 22Z"/><path d="M8 12H16"/><path d="M8 8H16"/><path d="M8 16H13"/></g></svg>',
  Solar.add:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M15 12L12 12M12 12L9 12M12 12L12 9M12 12L12 15"/></g></svg>',
  Solar.scanner:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M10 22C6.22876 22 4.34315 22 3.17157 20.8284C2 19.6569 2 18.7712 2 15"/><path d="M22 15C22 18.7712 22 19.6569 20.8284 20.8284C19.6569 22 17.7712 22 14 22"/><path d="M14 2C17.7712 2 19.6569 2 20.8284 3.17157C22 4.34315 22 5.22876 22 9"/><path d="M10 2C6.22876 2 4.34315 2 3.17157 3.17157C2 4.34315 2 5.22876 2 9"/><path d="M2 12H22"/></g></svg>',
  Solar.gallery:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M12 22C7.28595 22 4.92893 22 3.46447 20.5355C2 19.0711 2 16.714 2 12C2 7.28595 2 4.92893 3.46447 3.46447C4.92893 2 7.28595 2 12 2C16.714 2 19.0711 2 20.5355 3.46447C22 4.92893 22 7.28595 22 12C22 16.714 22 19.0711 20.5355 20.5355C19.0711 22 16.714 22 12 22Z"/><circle cx="16" cy="8" r="2"/><path d="M2 12.5001L3.75159 10.9675C4.66286 10.1702 6.03628 10.2159 6.89249 11.0721L11.1822 15.3618C11.8694 16.0491 12.9512 16.1428 13.7464 15.5839L14.0446 15.3744C15.1888 14.5702 16.7369 14.6634 17.7765 15.599L21 18.5001"/></g></svg>',
  Solar.folder:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M18 10L13 10"/><path d="M19.9998 6.23751C19.9989 5.94017 19.9946 5.76263 19.9743 5.60842C19.7971 4.26222 18.7378 3.2029 17.3916 3.02567C17.1966 3 16.9644 3 16.5 3H10"/><path d="M11 4L10.4497 3.44975C10.1763 3.17633 10.0396 3.03961 9.89594 2.92051C9.27652 2.40704 8.51665 2.09229 7.71557 2.01738C7.52976 2 7.33642 2 6.94975 2C6.06722 2 5.62595 2 5.25839 2.06935C3.64031 2.37464 2.37464 3.64031 2.06935 5.25839C2 5.62595 2 6.06722 2 6.94975V14C2 17.7712 2 19.6569 3.17157 20.8284C4.34315 22 6.22876 22 10 22H14C17.7712 22 19.6569 22 20.8284 20.8284C22 19.6569 22 17.7712 22 14V11.7979C22 9.16554 22 7.84935 21.2305 6.99383C21.1598 6.91514 21.0849 6.84024 21.0062 6.76946C20.7288 6.52002 20.4031 6.35144 19.9998 6.23751C19.159 6 17.9811 6 16.2021 6H15.8284C14.6747 6 14.0979 6 13.5604 5.84678C13.2651 5.7626 12.9804 5.64471 12.7121 5.49543C12.2237 5.22367 11.8158 4.81578 11 4Z"/></g></svg>',
  Solar.check:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path stroke-linejoin="round" d="M8.5 12.5L10.5 14.5L15.5 9.5"/></g></svg>',
  Solar.checkPlain:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M5 13L9 17L19 7"/></svg>',
  Solar.lock:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M8 22H16C18.8284 22 20.2426 22 21.1213 21.1213C22 20.2426 22 18.8284 22 16C22 13.1716 22 11.7574 21.1213 10.8787C20.2426 10 18.8284 10 16 10H8C5.17157 10 3.75736 10 2.87868 10.8787C2 11.7574 2 13.1716 2 16C2 18.8284 2 20.2426 2.87868 21.1213C3.75736 22 5.17157 22 8 22Z"/><circle cx="12" cy="16" r="2"/><path d="M6 10V8C6 4.68629 8.68629 2 12 2C15.3137 2 18 4.68629 18 8V10"/></g></svg>',
  Solar.camera:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><circle cx="12" cy="13" r="3"/><path d="M14.2222 21H9.77778C6.65675 21 5.09624 21 3.97524 20.2646C3.48995 19.9462 3.07328 19.5371 2.74902 19.0607C2 17.9601 2 16.4279 2 13.3636C2 10.2994 2 8.76721 2.74902 7.6666C3.07328 7.19014 3.48995 6.78104 3.97524 6.46268C4.69555 5.99013 5.59733 5.82123 6.978 5.76086C7.63685 5.76086 8.20412 5.27068 8.33333 4.63636C8.52715 3.68489 9.37805 3 10.3663 3H13.6337C14.6219 3 15.4728 3.68489 15.6667 4.63636C15.7959 5.27068 16.3631 5.76086 17.022 5.76086C18.4027 5.82123 19.3044 5.99013 20.0248 6.46268C20.51 6.78104 20.9267 7.19014 21.251 7.6666C22 8.76721 22 10.2994 22 13.3636C22 16.4279 22 17.9601 21.251 19.0607C20.9267 19.5371 20.51 19.9462 20.0248 20.2646C18.9038 21 17.3433 21 14.2222 21Z"/><path d="M19 10H18"/></g></svg>',
  Solar.pin:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M13.4629 21.6744C12.5343 22.1085 11.4657 22.1085 10.5371 21.6744C6.55332 19.8124 4 14.6055 4 10.1433C4 5.64588 7.58172 2 12 2C16.4183 2 20 5.64588 20 10.1433C20 14.6055 17.4467 19.8124 13.4629 21.6744Z"/><circle cx="12" cy="10" r="3"/></g></svg>',
  Solar.pdf:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><path d="M6 14.5H14"/><path d="M6 18H11.5"/><path d="M13 2.2627V5.0003C13 7.35732 13 8.53583 13.7322 9.26806C14.4645 10.0003 15.643 10.0003 18 10.0003H21.58"/><path stroke-linejoin="round" d="M3.17139 3.17157C4.34296 2 6.23851 2 10.0296 2C11.5546 2 12.3173 2.00011 13.0093 2.26562C13.7012 2.53114 14.2651 3.03857 15.3929 4.05365L19.3516 7.61621C20.6558 8.78998 21.3078 9.3774 21.6538 10.1543C21.9998 10.9312 22 11.8079 22 13.5625V14C22 17.7712 22 19.6566 20.8284 20.8281C19.6569 21.9997 17.7712 22 14 22L9.9969 21.9997C6.22761 21.9997 4.34284 21.9997 3.17157 20.8284C2 19.6569 2 17.7712 2 14V9.9982C2 6.22817 2 4.34296 3.17139 3.17157Z"/></g></svg>',
  Solar.danger:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 7V13"/><path stroke-linejoin="round" d="M12 16H12.0001"/></g></svg>',
  Solar.circle:
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="none" stroke="currentColor" stroke-width="1.5" d="M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12Z"/></svg>',
};
