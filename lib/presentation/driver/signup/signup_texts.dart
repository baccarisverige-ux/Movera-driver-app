import 'package:movera/core/content/driver_app_texts.dart';

/// Contract v0.18.166 (`signupV2`, owner 2026-11-26 "Oui, tout construire",
/// mockups PROPOSAL-signup-pro-v2 and PROPOSAL-upload-scan): the texts of
/// the new sign-up screens in en / fr / sv, kept in the deferred Profile
/// part like the country step's (web budget).
const Map<String, Map<String, String>> _texts = {
  // 1 · Vos informations
  'infoTitle': {
    'en': 'Your details',
    'fr': 'Vos informations',
    'sv': 'Dina uppgifter',
  },
  'infoBody': {
    'en': 'As they appear on your official papers.',
    'fr': "Telles qu'elles figurent sur vos papiers officiels.",
    'sv': 'Som de står i dina officiella papper.',
  },
  'step1': {'en': 'Step 1', 'fr': 'Étape 1', 'sv': 'Steg 1'},
  'country': {'en': 'Country', 'fr': 'Pays', 'sv': 'Land'},
  'countryFromPhone': {
    'en': 'Chosen from your number {0}',
    'fr': "Choisi d'après votre numéro {0}",
    'sv': 'Valt utifrån ditt nummer {0}',
  },
  'region': {'en': 'Region', 'fr': 'Région', 'sv': 'Region'},
  'choose': {'en': 'Choose', 'fr': 'Choisir', 'sv': 'Välj'},
  'you': {'en': 'YOU', 'fr': 'VOUS', 'sv': 'DU'},
  'phone': {'en': 'Phone', 'fr': 'Téléphone', 'sv': 'Telefon'},
  'firstName': {'en': 'First name', 'fr': 'Prénom', 'sv': 'Förnamn'},
  'lastName': {'en': 'Last name', 'fr': 'Nom', 'sv': 'Efternamn'},
  'email': {'en': 'E-mail', 'fr': 'E-mail', 'sv': 'E-post'},
  'emailHint': {
    'en': 'example@mail.com',
    'fr': 'exemple@mail.com',
    'sv': 'exempel@mail.se',
  },
  'dateOfBirth': {
    'en': 'Date of birth',
    'fr': 'Date de naissance',
    'sv': 'Födelsedatum',
  },
  'dateHint': {
    'en': 'DD / MM / YYYY',
    'fr': 'JJ / MM / AAAA',
    'sv': 'DD / MM / ÅÅÅÅ',
  },
  'personalNumber': {
    'en': 'Personal identity number',
    'fr': 'Personnummer',
    'sv': 'Personnummer',
  },
  'personalNumberHint': {
    'en': 'YYYYMMDD-XXXX',
    'fr': 'AAAAMMJJ-XXXX',
    'sv': 'ÅÅÅÅMMDD-XXXX',
  },
  'taxiNumber': {
    'en': 'Taxi driver licence, number',
    'fr': 'Carte taxi, numéro',
    'sv': 'Taxiförarlegitimation, nummer',
  },
  'taxiNumberHint': {
    'en': 'Number on your card',
    'fr': 'Numéro sur votre carte',
    'sv': 'Nummer på ditt kort',
  },
  'address': {'en': 'Home address', 'fr': 'Adresse', 'sv': 'Adress'},
  'street': {
    'en': 'Street and number',
    'fr': 'Numéro et rue',
    'sv': 'Gatuadress',
  },
  'streetHint': {
    'en': 'Start typing your address',
    'fr': 'Commencez à taper votre adresse',
    'sv': 'Börja skriva din adress',
  },
  'postalCode': {'en': 'Postal code', 'fr': 'Code postal', 'sv': 'Postnummer'},
  'city': {'en': 'City', 'fr': 'Ville', 'sv': 'Ort'},
  'language': {'en': 'Language', 'fr': 'Langue', 'sv': 'Språk'},
  'continue': {'en': 'Continue', 'fr': 'Continuer', 'sv': 'Fortsätt'},
  'required': {'en': 'Required', 'fr': 'Obligatoire', 'sv': 'Obligatoriskt'},
  'badEmail': {
    'en': 'Check the e-mail.',
    'fr': "Vérifiez l'e-mail.",
    'sv': 'Kontrollera e-postadressen.',
  },
  'badDate': {
    'en': 'Write the date as DD / MM / YYYY.',
    'fr': 'Écrivez la date comme JJ / MM / AAAA.',
    'sv': 'Skriv datumet som DD / MM / ÅÅÅÅ.',
  },
  'tooYoung': {
    'en': 'Drivers must be at least {0}.',
    'fr': 'Les chauffeurs doivent avoir au moins {0} ans.',
    'sv': 'Förare måste vara minst {0} år.',
  },
  'badPersonalNumber': {
    'en': 'Check the personal identity number (YYYYMMDD-XXXX).',
    'fr': 'Vérifiez le personnummer (AAAAMMJJ-XXXX).',
    'sv': 'Kontrollera personnumret (ÅÅÅÅMMDD-XXXX).',
  },
  'badTaxiNumber': {
    'en': 'Letters, digits, spaces and dashes only.',
    'fr': 'Lettres, chiffres, espaces et tirets seulement.',
    'sv': 'Endast bokstäver, siffror, mellanslag och bindestreck.',
  },
  'noCountryOpen': {
    'en': 'Choose your country.',
    'fr': 'Choisissez votre pays.',
    'sv': 'Välj ditt land.',
  },
  'saveError': {
    'en': 'Could not save. Check your connection and try again.',
    'fr':
        "L'enregistrement n'a pas pu se faire. Vérifiez la connexion et réessayez.",
    'sv': 'Det gick inte att spara. Kontrollera anslutningen och försök igen.',
  },
  'countryLocked': {
    'en': 'Your account is approved. Ask support to change your country.',
    'fr': 'Votre compte est validé. Demandez au support de changer votre pays.',
    'sv': 'Ditt konto är godkänt. Be supporten ändra ditt land.',
  },
  'fleetCountry': {
    'en':
        'Your fleet works in another country. Ask your fleet owner or support.',
    'fr':
        'Votre flotte travaille dans un autre pays. Demandez au propriétaire ou au support.',
    'sv':
        'Ditt åkeri arbetar i ett annat land. Fråga åkeriägaren eller supporten.',
  },
  // 2 · La liste
  'listTitle': {
    'en': "Let's set up your account",
    'fr': 'Configurons votre compte',
    'sv': 'Nu skapar vi ditt konto',
  },
  'listBody': {
    'en': 'Do the steps in any order. Everything is saved.',
    'fr':
        "Faites les étapes dans l'ordre que vous voulez. Tout est enregistré.",
    'sv': 'Gör stegen i valfri ordning. Allt sparas löpande.',
  },
  'later': {
    'en': 'Continue later',
    'fr': 'Continuer plus tard',
    'sv': 'Fortsätt senare',
  },
  'progress': {
    'en': 'Your progress',
    'fr': 'Votre progression',
    'sv': 'Dina framsteg',
  },
  'personal': {
    'en': 'Personal information',
    'fr': 'Informations personnelles',
    'sv': 'Personuppgifter',
  },
  'added': {'en': 'Added', 'fr': 'Ajouté', 'sv': 'Tillagd'},
  'profilePhoto': {
    'en': 'Profile photo',
    'fr': 'Photo de profil',
    'sv': 'Profilbild',
  },
  'youAre': {'en': 'You are', 'fr': 'Vous êtes', 'sv': 'Du är'},
  'youAreHintFR': {
    'en': 'With or without Kbis',
    'fr': 'Avec ou sans Kbis',
    'sv': 'Med eller utan Kbis',
  },
  'youAreHintSE': {
    'en': 'With or without own company',
    'fr': 'Avec ou sans société',
    'sv': 'Med eller utan eget företag',
  },
  'documents': {'en': 'Documents', 'fr': 'Documents', 'sv': 'Dokument'},
  'optional': {'en': 'Optional', 'fr': 'Facultatif', 'sv': 'Frivilligt'},
  'sendDocuments': {
    'en': 'Send the documents',
    'fr': 'Envoyer les documents',
    'sv': 'Skicka dokument',
  },
  'sendDocumentsHint': {
    'en': 'You can do it later',
    'fr': 'Vous pouvez le faire plus tard',
    'sv': 'Du kan göra det senare',
  },
  'documentsSent': {
    'en': '{0} sent',
    'fr': '{0} envoyé(s)',
    'sv': '{0} skickade',
  },
  'sendSignup': {
    'en': 'Send the registration',
    'fr': "Envoyer l'inscription",
    'sv': 'Skicka registreringen',
  },
  'finishFirst': {
    'en': 'Add your profile photo and say if you have a company first.',
    'fr':
        "Ajoutez d'abord votre photo de profil et dites si vous avez une société.",
    'sv': 'Lägg först till din profilbild och ange om du har eget företag.',
  },
  // 3 · Photo et statut
  'profileTitle': {
    'en': 'Your profile',
    'fr': 'Votre profil',
    'sv': 'Din profil',
  },
  'profileBody': {
    'en': 'Riders will see this photo.',
    'fr': 'Les clients verront cette photo.',
    'sv': 'Kunderna ser den här bilden.',
  },
  'tapPhoto': {
    'en': 'Tap to add a photo',
    'fr': 'Touchez pour ajouter une photo',
    'sv': 'Tryck för att lägga till foto',
  },
  'retakePhoto': {
    'en': 'Tap to take another photo',
    'fr': 'Touchez pour reprendre la photo',
    'sv': 'Tryck för att ta ett nytt foto',
  },
  'photoLocked': {
    'en': 'Your photo is approved. Contact support to change it.',
    'fr': 'Votre photo est validée. Contactez le support pour la changer.',
    'sv': 'Din bild är godkänd. Kontakta supporten för att byta den.',
  },
  'photoSending': {
    'en': 'Sending the photo…',
    'fr': 'Envoi de la photo…',
    'sv': 'Skickar bilden…',
  },
  'photoSent': {
    'en': 'Photo sent ✓',
    'fr': 'Photo envoyée ✓',
    'sv': 'Bilden skickad ✓',
  },
  'takePhoto': {
    'en': 'Take a photo',
    'fr': 'Prendre une photo',
    'sv': 'Ta ett foto',
  },
  'choosePhoto': {
    'en': 'Choose a photo',
    'fr': 'Choisir une photo',
    'sv': 'Välj ett foto',
  },
  'fleetFR': {
    'en': 'Driver with Kbis',
    'fr': 'Chauffeur avec Kbis',
    'sv': 'Förare med Kbis',
  },
  'fleetFRHint': {
    'en': 'I have my own VTC company',
    'fr': "J'ai ma propre société VTC",
    'sv': 'Jag har eget VTC-företag',
  },
  'driverFR': {
    'en': 'Driver without Kbis',
    'fr': 'Chauffeur sans Kbis',
    'sv': 'Förare utan Kbis',
  },
  'driverFRHint': {
    'en': 'I work for a VTC company',
    'fr': "Je suis salarié d'une société VTC",
    'sv': 'Jag är anställd på ett VTC-företag',
  },
  'fleetSE': {
    'en': 'Driver with own company',
    'fr': 'Chauffeur avec société',
    'sv': 'Förare med eget företag',
  },
  'fleetSEHint': {
    'en': 'I have my own taxi company',
    'fr': "J'ai ma propre société de taxi",
    'sv': 'Jag har eget taxiföretag',
  },
  'driverSE': {
    'en': 'Driver without own company',
    'fr': 'Chauffeur sans société',
    'sv': 'Förare utan eget företag',
  },
  'driverSEHint': {
    'en': 'I work for a taxi company',
    'fr': "Je suis salarié d'une société de taxi",
    'sv': 'Jag är anställd på ett taxiföretag',
  },
  'company': {
    'en': 'YOUR COMPANY',
    'fr': 'VOTRE SOCIÉTÉ',
    'sv': 'DITT FÖRETAG',
  },
  'companyName': {
    'en': 'Company name',
    'fr': 'Nom de la société',
    'sv': 'Företagsnamn',
  },
  'orgNumberFR': {
    'en': 'SIREN number',
    'fr': 'Numéro SIREN',
    'sv': 'SIREN-nummer',
  },
  'orgNumberSE': {
    'en': 'Organisation number',
    'fr': "Numéro d'organisation",
    'sv': 'Organisationsnummer',
  },
  'companyAddress': {
    'en': 'Company address',
    'fr': 'Adresse de la société',
    'sv': 'Företagets adress',
  },
  'typeLocked': {
    'en': 'This cannot change any more; ask support.',
    'fr': 'Ce choix ne peut plus changer ; demandez au support.',
    'sv': 'Det här kan inte längre ändras; fråga supporten.',
  },
  'done': {'en': 'Done', 'fr': 'Terminé', 'sv': 'Klar'},
  // 4 · Documents
  'docsTitle': {
    'en': 'Your documents',
    'fr': 'Vos documents',
    'sv': 'Dina dokument',
  },
  'docsBody': {
    'en': 'A sharp photo of the original. Send some now, the rest later.',
    'fr':
        "Photo nette de l'original. Envoyez une partie maintenant, le reste plus tard.",
    'sv': 'Tydligt foto av originalet. Skicka en del nu, resten senare.',
  },
  'docsYou': {'en': 'You', 'fr': 'Vous', 'sv': 'Du'},
  'docsCompany': {
    'en': 'Your company',
    'fr': 'Votre société',
    'sv': 'Ditt företag',
  },
  'withKbis': {'en': 'With Kbis', 'fr': 'Avec Kbis', 'sv': 'Med Kbis'},
  'withCompany': {
    'en': 'With own company',
    'fr': 'Avec société',
    'sv': 'Med eget företag',
  },
  'twoSides': {
    'en': 'Front and back',
    'fr': 'Recto et verso',
    'sv': 'Fram och bak',
  },
  'onePage': {'en': 'One page', 'fr': 'Une seule page', 'sv': 'En sida'},
  'add': {'en': 'Add', 'fr': 'Ajouter', 'sv': 'Lägg till'},
  'sent': {'en': 'Sent', 'fr': 'Envoyé', 'sv': 'Skickat'},
  'approved': {'en': 'Approved', 'fr': 'Validé', 'sv': 'Godkänt'},
  'rejected': {
    'en': 'Rejected · send again',
    'fr': 'Refusé · à renvoyer',
    'sv': 'Avvisat · skicka igen',
  },
  'noDocuments': {
    'en': 'No document is asked in your country yet.',
    'fr': "Aucun document n'est demandé dans votre pays pour l'instant.",
    'sv': 'Inga dokument begärs i ditt land ännu.',
  },
  // Ajouter sheet + scan
  'twoSidesPhotos': {
    'en': 'Front and back · 2 photos',
    'fr': 'Recto et verso · 2 photos',
    'sv': 'Fram och bak · 2 foton',
  },
  'onePagePhotos': {
    'en': 'One page · 1 photo or 1 file',
    'fr': 'Une seule page · 1 photo ou 1 fichier',
    'sv': 'En sida · 1 foto eller 1 fil',
  },
  'scanner': {'en': 'Scanner', 'fr': 'Scanner', 'sv': 'Skanna'},
  'scannerHint': {
    'en': 'Photo taken automatically',
    'fr': 'Photo prise automatiquement',
    'sv': 'Fotot tas automatiskt',
  },
  'recommended': {
    'en': 'Recommended',
    'fr': 'Conseillé',
    'sv': 'Rekommenderas',
  },
  'pickFile': {
    'en': 'Choose a photo or a file',
    'fr': 'Choisir une photo ou un fichier',
    'sv': 'Välj ett foto eller en fil',
  },
  'pickFileHint': {
    'en': 'Gallery, Files (PDF)',
    'fr': 'Galerie, Fichiers (PDF)',
    'sv': 'Bilder, Filer (PDF)',
  },
  'gallery': {'en': 'Gallery', 'fr': 'Galerie', 'sv': 'Bilder'},
  'files': {'en': 'Files (PDF)', 'fr': 'Fichiers (PDF)', 'sv': 'Filer (PDF)'},
  'front': {'en': 'Front', 'fr': 'Recto', 'sv': 'Framsida'},
  'back': {'en': 'Back', 'fr': 'Verso', 'sv': 'Baksida'},
  'stepOf': {
    'en': '{0} · {1} of 2',
    'fr': '{0} · {1} sur 2',
    'sv': '{0} · {1} av 2',
  },
  'placeFront': {
    'en': 'Place the front in the frame',
    'fr': 'Placez le recto dans le cadre',
    'sv': 'Lägg framsidan i ramen',
  },
  'placeBack': {
    'en': 'Place the back in the frame',
    'fr': 'Placez le verso dans le cadre',
    'sv': 'Lägg baksidan i ramen',
  },
  'autoHint': {
    'en': 'The photo is taken by itself when it is sharp',
    'fr': "La photo se prend toute seule quand c'est net",
    'sv': 'Fotot tas av sig självt när det är skarpt',
  },
  'frontSaved': {
    'en': 'Front saved · turn the card over',
    'fr': 'Recto enregistré · retournez la carte',
    'sv': 'Framsidan sparad · vänd på kortet',
  },
  'startScan': {
    'en': 'Open the scanner',
    'fr': 'Ouvrir le scanner',
    'sv': 'Öppna skannern',
  },
  'check': {'en': 'Check', 'fr': 'Vérifier', 'sv': 'Kontrollera'},
  'checkBody': {
    'en': 'Check that everything is readable: texts, photo, dates.',
    'fr': 'Vérifiez que tout est lisible : textes, photo, dates.',
    'sv': 'Kontrollera att allt går att läsa: text, foto, datum.',
  },
  'bothSharp': {
    'en': 'Both sides are sharp',
    'fr': 'Les deux faces sont nettes',
    'sv': 'Båda sidorna är skarpa',
  },
  'send': {'en': 'Send', 'fr': 'Envoyer', 'sv': 'Skicka'},
  'retake': {
    'en': 'Retake a photo',
    'fr': 'Reprendre une photo',
    'sv': 'Ta om ett foto',
  },
  'pdfFile': {'en': 'PDF file', 'fr': 'Fichier PDF', 'sv': 'PDF-fil'},
  'sending': {'en': 'Sending…', 'fr': 'Envoi…', 'sv': 'Skickar…'},
  'sentOk': {'en': 'Sent ✓', 'fr': 'Envoyé ✓', 'sv': 'Skickat ✓'},
  'sendFailed': {
    'en': 'Not sent. Check your connection and try again.',
    'fr': "Pas envoyé. Vérifiez la connexion et réessayez.",
    'sv': 'Inte skickat. Kontrollera anslutningen och försök igen.',
  },
  'sidesUnreadable': {
    'en':
        'This photo cannot be joined. Use the scanner, a JPEG or PNG photo, or one PDF with both sides.',
    'fr':
        'Cette photo ne peut pas être assemblée. Utilisez le scanner, une photo JPEG ou PNG, ou un seul PDF avec les deux faces.',
    'sv':
        'Det här fotot kan inte sättas ihop. Använd skannern, ett JPEG- eller PNG-foto eller en PDF med båda sidorna.',
  },
  'cameraBlocked': {
    'en':
        'The camera is blocked. Allow it in the phone settings, or choose a photo or a file.',
    'fr':
        "L'appareil photo est bloqué. Autorisez-le dans les réglages du téléphone, ou choisissez une photo ou un fichier.",
    'sv':
        'Kameran är blockerad. Tillåt den i telefonens inställningar, eller välj ett foto eller en fil.',
  },
};

/// The text [key] in the app's language (English for a missing one), with
/// `{0}`, `{1}` replaced by [args].
String st(String key, [List<Object> args = const []]) {
  final row = _texts[key];
  if (row == null) return key;
  var text = row[DriverAppTexts.language] ?? row['en']!;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i]}');
  }
  return text;
}

/// For tests: every key, in every language.
Map<String, Map<String, String>> get signupTextTable => _texts;
