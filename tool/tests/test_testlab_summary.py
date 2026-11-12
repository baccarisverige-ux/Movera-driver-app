import contextlib
import io
import json
import os
import pathlib
import sys
import tempfile
import unittest
import unittest.mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

import testlab_summary  # noqa: E402

# Made-up values in the shape of a phone number and a code (not real ones).
FAKE_PHONE = '+46000000000'
FAKE_CODE = '0000'
# Made-up, digits in a non-trivial order so a wrong digit order is caught
# (national part starts with 0: no real Swedish number looks like this).
FAKE_SPELLED = '+46000097531'
FAKE_SPELLED_CODE = '9876'
# Made-up rider number (national part starts with 0: not a real one).
FAKE_RIDER = '+46000086420'


class TestlabSummaryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        device = self.root / 'driver-device' / 'oriole-33-en_US-portrait'
        device.mkdir(parents=True)
        self.logcat = device / 'logcat'
        self.logcat.write_text('\n'.join([
            'I MoveraTL: run-time values handed to the test: 3',
            'I flutter : MOVERA-TL CHECK SIGN-IN PASS test driver reaches Home: Home is open',
            'I flutter : MOVERA-TL CHECK G24 FAIL position sends are taken: sends=0',
            'E AndroidRuntime: FATAL EXCEPTION: main',
            'E AndroidRuntime: java.lang.SecurityException: Neither user nor current process has android.permission.WAKE_LOCK.',
            'I am_instrument: -e movera_tl_phone %s -e movera_tl_code %s' % (FAKE_PHONE, FAKE_CODE),
        ]) + '\n')
        (device / 'test_result_1.xml').write_text(
            '<testsuite><testcase name="staging device checks"><failure>x</failure></testcase></testsuite>')
        self.shot = device / 'shot.png'
        self.shot.write_bytes(b'\x89PNG\0\0no values here')

    def tearDown(self):
        self.tmp.cleanup()

    def test_scrub_removes_values_from_text_files_only(self):
        changed = testlab_summary.scrub(str(self.root), [FAKE_PHONE, FAKE_CODE, '', '12'])
        self.assertEqual(changed, 1)
        text = self.logcat.read_text()
        self.assertNotIn(FAKE_PHONE, text)
        self.assertNotIn(FAKE_CODE, text)
        self.assertIn('[REDACTED]', text)

    def test_scrub_masks_spaced_dashed_and_bracketed_spellings(self):
        spellings = [
            '+46 00 009 75 31',      # as the app shows it (displayPhoneNumber)
            '000-009 75 31',         # Swedish dashed habit
            '000-0097531',
            '00 009 75 31',
            '+46-00-009-75-31',
            '+46 (0)00 009 75 31',
            '(000) 009-75-31',
            '0046000097531',
            '46000097531',
            '000097531',
        ]
        self.logcat.write_text(''.join(
            'E flutter : Exception: phone %s rejected, code %s\n' % (x, FAKE_SPELLED_CODE)
            for x in spellings))
        rc, message = testlab_summary.scrub_or_fail(
            str(self.root), testlab_summary.secret_values(FAKE_SPELLED, FAKE_SPELLED_CODE))
        self.assertEqual(rc, 0, message)
        text = self.logcat.read_text()
        digits_only = ''.join(c for c in text if c.isdigit())
        self.assertNotIn('97531', digits_only)
        self.assertNotIn(FAKE_SPELLED_CODE, text)
        self.assertEqual(text.count('[REDACTED]'), 2 * len(spellings))
        self.assertNotIn(FAKE_SPELLED, message)

    def test_display_forms_cover_the_app_display_and_national_forms(self):
        forms = testlab_summary.display_forms(FAKE_SPELLED)
        for f in ('+46000097531', '46000097531', '000097531', '0000097531',
                  '+46 00 009 75 31', '000 009 75 31', '000-009 75 31', '00-009-75-31'):
            self.assertIn(f, forms)

    def test_scrub_fails_safe_when_the_value_list_is_empty(self):
        for secrets in ([], [''], ['  ', '12']):
            rc, message = testlab_summary.scrub_or_fail(str(self.root), secrets)
            self.assertEqual(rc, 1)
            self.assertIn('no values to scrub', message)
        env = dict(os.environ)
        env.pop('TL_SCRUB', None)
        with unittest.mock.patch.dict(os.environ, env, clear=True), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(testlab_summary.main(['x', 'scrub', str(self.root)]), 1)

    def test_scrub_fails_safe_and_deletes_results_when_a_value_is_left(self):
        # A binary file is not rewritten; a value inside it must stop the upload.
        self.shot.write_bytes(b'\x89PNG\0\0' + FAKE_PHONE.encode())
        rc, message = testlab_summary.scrub_or_fail(str(self.root), [FAKE_PHONE, FAKE_CODE])
        self.assertEqual(rc, 1)
        self.assertIn('deleted', message)
        self.assertNotIn(FAKE_PHONE, message)
        self.assertFalse(self.root.exists())

    def test_scrub_rescan_finds_spaced_value_in_binary(self):
        self.shot.write_bytes(b'\x89PNG\0\0+46 00 009 75 31')
        rc, _ = testlab_summary.scrub_or_fail(str(self.root), [FAKE_SPELLED, FAKE_SPELLED_CODE])
        self.assertEqual(rc, 1)
        self.assertFalse(self.root.exists())

    def _driver(self, numbers, code=FAKE_SPELLED_CODE):
        out = tempfile.TemporaryDirectory()
        self.addCleanup(out.cleanup)
        buf = io.StringIO()
        env = {'TL_NUMBERS': numbers, 'TL_CODE': code}
        with contextlib.redirect_stdout(buf):
            rc = testlab_summary.write_driver(out.name, env)
        return rc, buf.getvalue(), pathlib.Path(out.name)

    def test_driver_prefers_se_d38_and_accepts_any_paste(self):
        doc = json.dumps({'browser': {'SE': {'driver': FAKE_PHONE}},
                          'se': {'d38': '+46 00-009 75 31'}})
        for pasted in (doc, 'MOVERA_TEST_NUMBERS=' + doc, 'OTHER_NAME=' + doc,
                       "'" + doc + "'", json.dumps(doc)[1:-1]):
            rc, printed, out = self._driver(pasted)
            self.assertEqual(rc, 0, printed)
            self.assertEqual((out / 'phone').read_text(), FAKE_SPELLED)
            self.assertEqual((out / 'code').read_text(), FAKE_SPELLED_CODE)
            self.assertIn('se.d38', printed)
            scrub = (out / 'scrub').read_text().splitlines()
            self.assertIn('+46 00 009 75 31', scrub)
            self.assertIn(FAKE_SPELLED_CODE, scrub)
            masked = [l[len('::add-mask::'):] for l in printed.splitlines() if l.startswith('::add-mask::')]
            self.assertEqual(sorted(masked), sorted(scrub))
            # Nothing but mask lines may carry a value.
            for line in printed.splitlines():
                if not line.startswith('::add-mask::'):
                    self.assertNotIn('97531', line.replace(' ', '').replace('-', ''))
                    self.assertNotIn(FAKE_SPELLED_CODE, line)

    def test_driver_falls_back_to_browser_driver(self):
        rc, printed, out = self._driver(json.dumps({'browser': {'SE': {'driver': '+46 00 009 75 31'}}}))
        self.assertEqual(rc, 0, printed)
        self.assertEqual((out / 'phone').read_text(), FAKE_SPELLED)
        self.assertIn('browser.SE.driver', printed)

    def test_driver_rejects_bad_number_or_code_without_printing_them(self):
        cases = [
            (json.dumps({'se': {'d38': '+46 12'}}), FAKE_SPELLED_CODE, 'not a phone number'),
            (json.dumps({'se': {'d38': FAKE_SPELLED}}), '98~7=6', 'not 4-8 digits'),
            (json.dumps({'se': {'d38': FAKE_SPELLED}}), '12', 'not 4-8 digits'),
            (json.dumps({'se': {}}), FAKE_SPELLED_CODE, 'no se.d38'),
            ('not json ' + FAKE_SPELLED, FAKE_SPELLED_CODE, 'is not JSON'),
        ]
        for numbers, code, why in cases:
            rc, printed, out = self._driver(numbers, code)
            self.assertEqual(rc, 1)
            self.assertIn(why, printed)
            self.assertNotIn('::add-mask::', printed)
            self.assertNotIn('97531', printed)
            self.assertNotIn('98~7', printed)
            self.assertFalse((out / 'phone').exists())

    def test_normalise_number_spellings(self):
        for x in ('+46 00 009 75 31', '+46-00-009-75-31', '+46 (0)00 009 75 31', '0046000097531'):
            self.assertEqual(testlab_summary.normalise_number(x), FAKE_SPELLED)

    def test_summary_reads_logcat_checks_crashes_and_junit(self):
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('| SIGN-IN  | PASS |', text)
        self.assertIn('| G24  | FAIL |', text)
        self.assertIn('SecurityException', text)
        self.assertIn('failures=1', text)
        self.assertNotIn('MOVERA-TL CHECK', text.split('Crash / error lines')[1])

    def test_summary_json_wins_over_logcat(self):
        (self.root / 'summary.json').write_text(json.dumps([
            {'id': 'G17', 'title': 'SOS numbers', 'outcome': 'pass', 'detail': 'zone=Z001'},
        ]))
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('| G17 SOS numbers | PASS | zone=Z001 |', text)
        self.assertNotIn('G24', text.split('JUnit')[0])

    def test_nothing_found_says_not_checked(self):
        empty = tempfile.TemporaryDirectory()
        self.addCleanup(empty.cleanup)
        self.assertIn('NOT CHECKED', testlab_summary.summary_text(empty.name))

    def test_skip_line_says_not_checked(self):
        self.logcat.write_text('I flutter : MOVERA-TL SKIP all checks: no test number at run time\n')
        self.assertIn('NOT CHECKED: SKIP all checks', testlab_summary.summary_text(str(self.root)))

    def test_workflow_passes_numbers_only_at_run_time(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        text = workflow.read_text()
        job = text.split('  device-checks:', 1)[1]
        self.assertIn('--type instrumentation', job)
        self.assertIn('--environment-variables', job)
        self.assertIn('testlab_summary.py "$mode"', job)
        self.assertIn('mode=driver', job)
        tool = (pathlib.Path(__file__).resolve().parents[1] / 'testlab_summary.py').read_text()
        self.assertIn('::add-mask::', tool)
        self.assertIn('testlab_summary.py scrub', job)
        # Fail-safe upload: only after a successful scrub; no `|| true` there.
        self.assertIn('id: scrub', job)
        upload = job.split('actions/upload-artifact', 1)[1].split('\n      - ', 1)[0]
        self.assertIn("steps.scrub.outcome == 'success'", upload)
        scrub_step = job.split('id: scrub', 1)[1].split('\n      - ', 1)[0]
        self.assertNotIn('|| true', scrub_step)
        # a12: no "NAME=" literal of the secret in any workflow.
        self.assertNotIn('MOVERA_TEST_NUMBERS' + '=', text)
        self.assertIn('name: testlab-results', job)
        self.assertIn('--timeout "$TL_TIMEOUT"', job)
        self.assertIn('tl_timeout=9m', job)
        self.assertIn('tl_timeout=20m', job)
        # The build lines carry no test number or code.
        build = job.split('flutter build apk --debug', 1)[1].split('mkdir -p out', 1)[0]
        self.assertNotIn('tl/phone', build)
        self.assertNotIn('TL_NUMBERS', build)
        on = text.split('jobs:', 1)[0]
        self.assertNotIn('pull_request', on)
        self.assertNotIn('push:', on)

    def _trip(self, numbers, code=FAKE_SPELLED_CODE):
        out = tempfile.TemporaryDirectory()
        self.addCleanup(out.cleanup)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = testlab_summary.write_driver(out.name, {'TL_NUMBERS': numbers, 'TL_CODE': code},
                                              with_rider=True)
        return rc, buf.getvalue(), pathlib.Path(out.name)

    def test_trip_picks_big_test_rider_and_masks_every_spelling(self):
        doc = json.dumps({'browser': {'SE': {'rider': FAKE_PHONE, 'driver': FAKE_PHONE}},
                          'se': {'d38': FAKE_SPELLED, 'r35': '+46 00-008 64 20', 'r36': FAKE_PHONE}})
        rc, printed, out = self._trip(doc)
        self.assertEqual(rc, 0, printed)
        self.assertEqual((out / 'rider_phone').read_text(), FAKE_RIDER)
        self.assertEqual((out / 'phone').read_text(), FAKE_SPELLED)
        self.assertIn('se.r35', printed)
        scrub = (out / 'scrub').read_text().splitlines()
        for f in ('+46 00 008 64 20', '000-008 64 20', '0000086420', FAKE_RIDER, '+46 00 009 75 31'):
            self.assertIn(f, scrub)
        masked = [l[len('::add-mask::'):] for l in printed.splitlines() if l.startswith('::add-mask::')]
        self.assertEqual(sorted(masked), sorted(scrub))
        for line in printed.splitlines():
            if not line.startswith('::add-mask::'):
                digits = ''.join(c for c in line if c.isdigit())
                self.assertNotIn('86420', digits)
                self.assertNotIn('97531', digits)

    def test_trip_rider_fallback_and_never_a_base_number(self):
        rc, printed, out = self._trip(json.dumps({'se': {'d38': FAKE_SPELLED, 'r36': FAKE_RIDER}}))
        self.assertEqual(rc, 0, printed)
        self.assertIn('se.r36', printed)
        rc, printed, out = self._trip(json.dumps(
            {'se': {'d38': FAKE_SPELLED}, 'browser': {'SE': {'rider': FAKE_RIDER}}}))
        self.assertEqual(rc, 1)
        self.assertIn('no se.r35 or se.r36 entry', printed)
        self.assertNotIn('::add-mask::', printed)
        self.assertFalse((out / 'rider_phone').exists())
        rc, printed, _ = self._trip(json.dumps({'se': {'d38': FAKE_SPELLED, 'r35': FAKE_SPELLED}}))
        self.assertEqual(rc, 1)
        self.assertIn('same number', printed)
        self.assertNotIn('97531', printed)

    def test_scrub_removes_rider_spellings_and_fails_safe_on_leftover(self):
        self.logcat.write_text('E flutter : rider +46 00 008 64 20 / 000-008 64 20 / %s\n' % FAKE_RIDER)
        values = testlab_summary.secret_values(FAKE_SPELLED, FAKE_SPELLED_CODE) + \
            testlab_summary.display_forms(FAKE_RIDER)
        rc, message = testlab_summary.scrub_or_fail(str(self.root), values)
        self.assertEqual(rc, 0, message)
        self.assertNotIn('86420', ''.join(c for c in self.logcat.read_text() if c.isdigit()))
        self.shot.write_bytes(b'\x89PNG\0\0' + FAKE_RIDER.encode())
        rc, _ = testlab_summary.scrub_or_fail(str(self.root), values)
        self.assertEqual(rc, 1)
        self.assertFalse(self.root.exists())

    def test_summary_shows_transitions_table(self):
        rows = [
            {'name': 'offer->trip', 'frames': 40, 'missed': 2, 'worstMs': 31.5, 'gets': 3,
             'recreatedMaps': [], 'loaderSamples': 0, 'blankSamples': 0, 'failedCalls': [],
             'exceptions': [], 'smooth': True, 'reload': False, 'errors': False,
             'build': 'debug build, indicative'},
            {'name': 'done->home', 'frames': 12, 'missed': 9, 'worstMs': 250.0, 'gets': 6,
             'recreatedMaps': ['home (Home came back with a new map)'], 'loaderSamples': 1,
             'blankSamples': 0, 'failedCalls': ['GET /api/v1/x -> 500'], 'exceptions': [],
             'smooth': False, 'reload': True, 'errors': True, 'build': 'debug build, indicative'},
        ]
        (self.root / 'transitions.json').write_text(json.dumps(rows))
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('### Screen changes', text)
        self.assertIn('| offer->trip | 40 | 2 | 31.5 | 3 | - | 0/0 | - | PASS |', text)
        self.assertIn('FAIL FREEZE RELOAD ERRORS', text)
        self.assertIn('debug build, indicative', text)
        (self.root / 'transitions.json').unlink()
        self.logcat.write_text('I flutter : MOVERA-TL TRANSITIONS-JSON %s\n' % json.dumps(rows[:1]))
        self.assertIn('| offer->trip |', testlab_summary.summary_text(str(self.root)))

    def test_summary_notes_the_5x5_shared_accounts_rule(self):
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('5x5', text)
        self.assertIn('One device-check run at a time', text)

    def test_workflow_runs_one_device_check_at_a_time(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        job = workflow.read_text().split('  device-checks:', 1)[1].split('    steps:', 1)[0]
        self.assertIn('concurrency:', job)
        self.assertIn('group: movera-device-checks-d38-r35', job)
        self.assertIn('cancel-in-progress: false', job)

    def test_workflow_trip_passes_rider_only_at_run_time(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        job = workflow.read_text().split('  device-checks:', 1)[1]
        self.assertIn('- trip-lifecycle', workflow.read_text())
        self.assertIn('- trip-scheduled', workflow.read_text())
        self.assertIn('testlab_summary.py "$mode"', job)
        self.assertIn('movera_tl_rider_phone=${rider}', job)
        self.assertIn('integration_test/trip_lifecycle_test.dart', job)
        build = job.split('flutter build apk --debug', 1)[1].split('mkdir -p out', 1)[0]
        self.assertNotIn('rider_phone', build)
        java = (pathlib.Path(__file__).resolve().parents[2] /
                'android/app/src/androidTest/java/se/movera/driver/MainActivityTest.java').read_text()
        self.assertIn('{"movera_tl_rider_phone", "MOVERA_TL_RIDER_PHONE"}', java)


if __name__ == '__main__':
    unittest.main()
