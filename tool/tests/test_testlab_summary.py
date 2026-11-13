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

    def test_fail_rows_keep_the_missed_key_and_more_detail(self):
        (self.root / 'driver-device' / 'oriole-33-en_US-portrait' / 'summary.json').write_text(json.dumps([
            {'id': 'ARRIVE', 'title': 'at the pickup', 'outcome': 'fail',
             'detail': 'MISSED: "active-ride-arrived-button" not tappable -- ' + 'x' * 600 + 'END'},
            {'id': 'G24', 'title': 'sends', 'outcome': 'pass', 'detail': 'y' * 600 + 'END'},
        ]))
        text = testlab_summary.summary_text(str(self.root))
        self.assertIn('MISSED: "active-ride-arrived-button" not tappable -- ', text)
        self.assertIn('x' * 600 + 'END', text)
        self.assertNotIn('y' * 600, text)
        self.assertIn('y' * 400, text)

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
        self.assertIn('tl_timeout=25m', job)  # run 6: Test Lab after the test's own 18m
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

    # --- verdict (run 6, 2026-11-12: a FALSE PASS) -------------------------

    def _run_dir(self, logcat_lines, junit_tests, gcloud='', outcome='Passed', summary_json=False):
        """A results folder in the shape Test Lab + the workflow leave it."""
        run = tempfile.TemporaryDirectory()
        self.addCleanup(run.cleanup)
        root = pathlib.Path(run.name)
        device = root / '43292982501-1' / 'oriole-33-en_US-portrait'
        device.mkdir(parents=True)
        (device / 'logcat').write_text('\n'.join(logcat_lines) + '\n')
        cases = ''.join('<testcase name="t%d"/>' % i for i in range(junit_tests))
        (device / 'test_result_1.xml').write_text(
            '<testsuites><testsuite name="" tests="%d" failures="0" errors="0" skipped="0">%s'
            '</testsuite></testsuites>' % (junit_tests, cases))
        if summary_json:
            (device / 'summary.json').write_text('[]')
        (root / 'gcloud.txt').write_text(gcloud)
        (root / 'testlab.json').write_text(json.dumps([
            {'axis_value': 'oriole-33-en_US-portrait', 'outcome': outcome, 'test_details': '--'}]))
        return root

    RUN6_LOGCAT = [
        'I flutter : MOVERA-TL CHECK SIGN-IN PASS test driver reaches Home: Home is open',
        'I flutter : MOVERA-TL CHECK TRANSITION:home->offer:SMOOTH FAIL frames: worst 210 ms',
        'I flutter : MOVERA-TL CHECK TRANSITION:offer->trip:SMOOTH FAIL frames: worst 593 ms',
        'I flutter : MOVERA-TL CHECK TRANSITION:menu-back-1:SMOOTH PASS frames ok',
        'I flutter : 18:00 +0: trip lifecycle [E]  TimeoutException after 0:18:00.000000: '
        'Test timed out after 18 minutes.',
        'I TestRunner: run finished: 0 tests, 0 failed, 0 ignored',
    ]
    RUN6_GCLOUD = ('Test is Running\nStarting attempt 1.\nA non-retryable error occurred.\n'
                   'Test is Pending\nInstrumentation testing complete.\n')

    def test_verdict_fails_run6_false_pass_with_one_error_per_reason(self):
        root = self._run_dir(self.RUN6_LOGCAT, 0, gcloud=self.RUN6_GCLOUD)
        # The old Result step looked only at the gcloud exit code: run 6 had 0.
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = testlab_summary.verdict(str(root), '0')
        self.assertEqual(rc, 1)
        errors = [l for l in out.getvalue().splitlines() if l.startswith('::error::')]
        text = '\n'.join(errors)
        self.assertIn('JUnit has 0 tests', text)
        self.assertIn('no MOVERA-TL END line', text)
        self.assertIn('no SUMMARY-JSON line', text)
        self.assertIn('TRANSITION:home->offer:SMOOTH', text)
        self.assertIn('TRANSITION:offer->trip:SMOOTH', text)
        self.assertNotIn('menu-back-1', text)
        self.assertIn('Test timed out after', text)
        self.assertIn('non-retryable error', text)
        self.assertNotIn('exit code', text)
        self.assertNotIn('outcome', text)
        self.assertEqual(len(errors), 6)

    def test_verdict_main_reads_rc_from_env_and_fails_run6(self):
        root = self._run_dir(self.RUN6_LOGCAT, 0, gcloud=self.RUN6_GCLOUD)
        with unittest.mock.patch.dict(os.environ, {'RC': '0'}), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(testlab_summary.main(['x', 'verdict', str(root)]), 1)

    GOOD_LOGCAT = [
        'I flutter : MOVERA-TL CHECK SIGN-IN PASS test driver reaches Home: Home is open',
        'I flutter : MOVERA-TL CHECK OFFLINE PASS Go offline is taken: server says offline',
        'I flutter : MOVERA-TL SUMMARY passed=2 failed=0 skipped=0',
        'I flutter : MOVERA-TL SUMMARY-JSON []',
        'I flutter : MOVERA-TL END checks=2 failed=0 cleanup=none offline=pass',
    ]

    def test_verdict_passes_a_clean_run(self):
        root = self._run_dir(self.GOOD_LOGCAT, 1, gcloud='Instrumentation testing complete.\n')
        self.assertEqual(testlab_summary.verdict_reasons(str(root), '0'), [])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(testlab_summary.verdict(str(root), '0'), 0)

    def test_verdict_each_reason_alone(self):
        cases = {
            'exit code 10': dict(rc='10'),
            'exit code missing': dict(rc=''),
            'JUnit has 0 tests': dict(tests=0),
            'no MOVERA-TL END line': dict(drop='END '),
            'no SUMMARY-JSON line': dict(drop='SUMMARY-JSON '),
            'check(s) FAIL: RUN': dict(add='I flutter : MOVERA-TL CHECK RUN FAIL hung: no pump returned in SWITCH-1'),
            'Test timed out after': dict(add='I flutter : Test timed out after 18 minutes.'),
            'non-retryable error': dict(gcloud='A non-retryable error occurred.\n'),
            'outcome: Inconclusive': dict(outcome='Inconclusive'),
        }
        for want, c in cases.items():
            with self.subTest(want):
                lines = [l for l in self.GOOD_LOGCAT if not (c.get('drop') and c['drop'] in l)]
                if c.get('add'):
                    lines.append(c['add'])
                root = self._run_dir(lines, c.get('tests', 1), gcloud=c.get('gcloud', ''),
                                     outcome=c.get('outcome', 'Passed'))
                reasons = testlab_summary.verdict_reasons(str(root), c.get('rc', '0'))
                self.assertEqual(len(reasons), 1, reasons)
                self.assertIn(want, reasons[0])

    def test_verdict_summary_json_file_counts_and_skip_explains_no_end(self):
        lines = [l for l in self.GOOD_LOGCAT if 'SUMMARY-JSON' not in l]
        root = self._run_dir(lines, 1, summary_json=True)
        self.assertEqual(testlab_summary.verdict_reasons(str(root), '0'), [])
        skip = self._run_dir(['I flutter : MOVERA-TL SKIP all checks: no test number at run time'], 1)
        self.assertEqual(testlab_summary.verdict_reasons(str(skip), '0'), [])

    def test_verdict_missing_testlab_json_fails(self):
        root = self._run_dir(self.GOOD_LOGCAT, 1)
        (root / 'testlab.json').unlink()
        reasons = testlab_summary.verdict_reasons(str(root), '0')
        self.assertEqual(len(reasons), 1)
        self.assertIn('testlab.json: no outcome', reasons[0])

    def test_workflow_result_runs_verdict_after_scrub_and_upload(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        job = workflow.read_text().split('  device-checks:', 1)[1]
        scrub = job.index('testlab_summary.py scrub testlab-results')
        upload = job.index('actions/upload-artifact@v4')
        result = job.index('- name: Result')
        verdict = job.index('testlab_summary.py verdict testlab-results')
        self.assertLess(scrub, upload)
        self.assertLess(upload, result)
        self.assertLess(result, verdict)
        step = job[result:]
        self.assertNotIn('Device checks passed on Test Lab', step)
        self.assertIn('RC: ${{ steps.run.outputs.rc }}', step)
        self.assertNotIn('always()', step.split('run:', 1)[0])

    def test_workflow_test_lab_timeout_beats_the_trip_test_timeout(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        text = workflow.read_text()
        for name in ('trip-lifecycle', 'trip-scheduled'):
            line = next(l for l in text.splitlines() if l.strip().startswith(name + ')'))
            self.assertIn('tl_timeout=25m', line)

    # --- Lock step: mirror of the rider repo's G31 lock (supervisor GO 4c31475a)

    def _cmd(self, content, *extra, command='count-runs'):
        f = self.root / 'answer.json'
        f.write_text(content)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = testlab_summary.main(['testlab_summary.py', command, str(f), *extra])
        return rc, buf.getvalue().strip()

    def test_count_runs_reads_total_count(self):
        self.assertEqual(self._cmd(json.dumps({'total_count': 0, 'workflow_runs': []})), (0, '0'))
        self.assertEqual(self._cmd(json.dumps({'total_count': 2, 'workflow_runs': [{}]})), (0, '2'))

    def test_count_runs_fails_closed_on_any_other_shape(self):
        for bad in ('', 'not json', '[]', '{}', json.dumps({'total_count': -1}),
                    json.dumps({'total_count': '1'}), json.dumps({'total_count': True}),
                    json.dumps({'total_count': 1.5}),
                    json.dumps({'message': 'API rate limit exceeded'}),
                    json.dumps({'message': 'Not Found', 'status': '404'}),
                    json.dumps({'total_count': 0, 'workflow_runs': 'x'})):
            rc, out = self._cmd(bad)
            self.assertEqual(rc, 1, bad)
            self.assertEqual(out, '', bad)
        self.assertIsNone(testlab_summary.count_runs(str(self.root / 'missing.json')))

    WF = '.github/workflows/android-test-apk.yml'

    def test_workflow_missing_only_on_a_whole_list_without_the_file(self):
        other = {'path': '.github/workflows/ci.yml', 'name': 'CI'}
        self.assertEqual(self._cmd(json.dumps({'total_count': 1, 'workflows': [other]}),
                                   self.WF, command='workflow-missing'), (0, ''))
        self.assertEqual(self._cmd(json.dumps({'total_count': 0, 'workflows': []}),
                                   self.WF, command='workflow-missing'), (0, ''))

    def test_workflow_missing_fails_closed_when_present_or_unclear(self):
        here = {'path': self.WF, 'name': 'Android test APK (staging)'}
        other = {'path': '.github/workflows/ci.yml'}
        for bad in ('', 'not json', '[]', '{}',
                    json.dumps({'message': 'Not Found'}),
                    json.dumps({'message': 'API rate limit exceeded'}),
                    json.dumps({'total_count': 2, 'workflows': [here, other]}),
                    # more workflows than on this page: the file may be on the next one
                    json.dumps({'total_count': 120, 'workflows': [other]}),
                    json.dumps({'total_count': True, 'workflows': []}),
                    json.dumps({'total_count': 1, 'workflows': 'x'}),
                    json.dumps({'total_count': 1, 'workflows': [{'name': 'no path'}]}),
                    json.dumps({'total_count': 1, 'workflows': ['x']})):
            rc, out = self._cmd(bad, self.WF, command='workflow-missing')
            self.assertEqual(rc, 1, bad)
            self.assertEqual(out, '', bad)
        self.assertFalse(testlab_summary.workflow_missing(str(self.root / 'missing.json'), self.WF))
        # Wrong argument count is a usage error, never a "missing".
        f = self.root / 'answer.json'
        f.write_text(json.dumps({'total_count': 0, 'workflows': []}))
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(testlab_summary.main(['t', 'workflow-missing', str(f)]), 2)

    def _job(self):
        workflow = pathlib.Path(__file__).resolve().parents[2] / '.github/workflows/android-test-apk.yml'
        return workflow.read_text().split('  device-checks:', 1)[1]

    def test_workflow_lock_is_short_and_fail_closed(self):
        job = self._job()
        lock = job.split('id: lock', 1)[1].split('\n      - ', 1)[0]
        self.assertIn('baccarisverige-ux/movera-rider-app/actions/workflows', lock)
        self.assertIn('android-test-apk.yml/runs', lock)
        self.assertIn('for status in in_progress queued', lock)
        self.assertIn('timeout-minutes: 16', lock)
        self.assertIn('for round in $(seq 1 14)', lock)
        self.assertIn('for try in 1 2 3', lock)
        self.assertIn('testlab_summary.py count-runs', lock)
        self.assertIn('GH_TOKEN: ${{ github.token }}', lock)
        # free only after a round where both reads gave 0; unreadable or
        # still busy -> not free (no Test Lab), never a fail-open "going on".
        self.assertEqual(lock.count('free=true'), 1)
        self.assertIn('if [ "$busy" -eq 0 ]; then echo "free=true"', lock)
        self.assertEqual(lock.count('free=false'), 2)
        self.assertEqual(lock.count('NOT CHECKED'), 2)
        self.assertNotIn('going on', lock)
        self.assertIn('sleep 60', lock)
        # A 404 is "0 runs" only with a 200 whole workflow list without the file.
        self.assertIn('[ "$code" = 200 ] && n="$(python3 -I tool/testlab_summary.py count-runs', lock)
        self.assertIn('[ "$code" = 404 ]', lock)
        self.assertIn('[ "$lcode" = 200 ]', lock)
        self.assertIn('testlab_summary.py workflow-missing "$list" "$wf"', lock)
        self.assertIn('wf=".github/workflows/android-test-apk.yml"', lock)
        self.assertNotIn(' -f', lock.replace('-fsS', ''))  # codes read with -w, not curl -f
        # The lock prints counts only: no answer file is ever printed.
        self.assertNotIn('cat ', lock)
        self.assertNotIn('set -x', lock)
        # The lock is the first step after checkout; the driver step waits on it.
        self.assertLess(job.index('id: lock'), job.index('id: driver'))
        driver = job.split('id: driver', 1)[1].split('run: |', 1)[0]
        self.assertIn("if: steps.lock.outputs.free == 'true'", driver)

    def test_workflow_job_time_fits_lock_build_test_lab_and_upload(self):
        import re as _re
        job = self._job()
        head = job.split('    steps:', 1)[0]
        job_min = int(_re.search(r'timeout-minutes: (\d+)', head).group(1))
        lock_min = int(_re.search(r'id: lock\n\s+timeout-minutes: (\d+)', job).group(1))
        run = job.split('id: run', 1)[1].split('\n      - ', 1)[0]
        tl_step = int(_re.search(r'timeout-minutes: (\d+)', run).group(1))
        self.assertIn('tl_timeout=25m', job)
        self.assertGreaterEqual(tl_step, 25 + 3)
        # lock + set-up/build (~15) + wake (2) + Test Lab step + results (~5)
        self.assertLessEqual(lock_min + 15 + 2 + tl_step + 5, job_min)
        self.assertLessEqual(lock_min, 16)

if __name__ == '__main__':
    unittest.main()
