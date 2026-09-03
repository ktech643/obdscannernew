import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/app_providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/blueprint.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/icons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/scaffold.dart';
import '../pro/paywall_screen.dart';

Route<void> _route(Widget child) =>
    PageRouteBuilder(pageBuilder: (_, _, _) => child);

/// G1 — sign in. An account is genuinely optional, and the screen says so
/// twice: once as an action, once as a closing fact.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.read<AccountProvider>();
    return Screen(
      gutter: T.gutterWide,
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      children: [
        Text('Sign in to Torque', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          'An account keeps your garage and service history in step across '
          "devices. It isn't required to use the app.",
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        SecondaryButton(
          'Sign in with Apple',
          onPressed: () {
            a.signIn();
            Navigator.of(context).pop();
          },
          icon: Lu.apple,
        ),
        const SizedBox(height: 18),
        const _OrRule(),
        const SizedBox(height: 18),
        Field(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        Field(label: 'Password', controller: _password, obscure: true),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: InlineAction(
            'Forgot your password?',
            onPressed: () =>
                Navigator.of(context)
                    .push(_route(const ForgotPasswordScreen())),
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          'Sign in',
          onPressed: () {
            a.signIn(email: _email.text);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('New to Torque?', style: Type.bodyMuted),
            InlineAction(
              'Create an account',
              onPressed: () =>
                  Navigator.of(context)
                      .push(_route(const CreateAccountScreen())),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GhostButton(
          'Continue without an account',
          color: T.neutral700,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 14),
        Text(
          'Reading codes and live data works with no account, no sign-in and no '
          'internet.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

class _OrRule extends StatelessWidget {
  const _OrRule();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: SizedBox(height: 1, child: ColoredBox(color: T.divider)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or', style: Type.rowSecondary),
      ),
      const Expanded(
        child: SizedBox(height: 1, child: ColoredBox(color: T.divider)),
      ),
    ],
  );
}

/// G2 — create account. Only an email and a password; no phone number and no
/// name required.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.read<AccountProvider>();
    final pw = _password.text;
    final score = AccountProvider.strengthOf(pw);

    return Screen(
      gutter: T.gutterWide,
      backLabel: 'Sign in',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        gutter: T.gutterWide,
        children: [
          PrimaryButton(
            'Create account',
            onPressed: _agreed && score >= 3
                ? () {
                    a.createAccount(_email.text);
                    Navigator.of(context)
                        .pushReplacement(_route(const VerifyEmailScreen()));
                  }
                : null,
          ),
          const SizedBox(height: 6),
          GhostButton(
            'Sign up with Apple instead',
            onPressed: () => notImplementedHere(
              context,
              'Sign in with Apple is handled by iOS.',
            ),
          ),
        ],
      ),
      children: [
        Text('Create an account', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          'Only an email and a password. No phone number, no name required.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        Field(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        Field(label: 'Password', controller: _password, obscure: true),
        if (pw.isNotEmpty) ...[
          const SizedBox(height: 10),
          _StrengthMeter(score: score),
          const SizedBox(height: 12),
          // Rules are shown as a live checklist, not as an error after submit.
          for (final r in AccountProvider.passwordRules)
            _RuleRow(label: r.rule, met: r.test(pw)),
        ],
        const SizedBox(height: 16),
        const Field(label: 'Confirm password', obscure: true),
        const SizedBox(height: 16),
        AppCheckbox(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v),
          label: 'I agree to the Terms and the Privacy Policy.',
        ),
      ],
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = switch (score) {
      0 || 1 => T.fault,
      2 => T.cautionText,
      _ => T.passText,
    };
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
              color: i < score ? color : T.neutral300,
            ),
          ),
        const SizedBox(width: 12),
        Text(AccountProvider.strengthLabel(score), style: Type.chip(color)),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icn(
          met ? Lu.check : Lu.minus,
          size: 13,
          color: met ? T.passText : T.neutral500,
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: Type.rowSecondary.copyWith(
            color: met ? T.passText : T.neutral700,
          ),
        ),
      ],
    ),
  );
}

/// G3 — verify email. We only ever send a code, never a magic link, and the
/// screen says so — link-based sign-in is the phishing surface here.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _digits = List.filled(6, '');

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AccountProvider>();
    return Screen(
      gutter: T.gutterWide,
      backLabel: 'Back',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        gutter: T.gutterWide,
        children: [
          PrimaryButton(
            'Verify and continue',
            onPressed: () {
              a.verify();
              Navigator.of(context)
                  .pushReplacement(_route(const FinishProfileScreen()));
            },
          ),
          const SizedBox(height: 6),
          GhostButton(
            'Do this later',
            color: T.neutral700,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      children: [
        Text('Check your email', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          'We sent a six-digit code to ${a.email}. It expires in 15 minutes.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: Container(
                  height: 62,
                  margin: EdgeInsets.only(right: i == 5 ? 0 : 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _digits[i].isEmpty ? T.divider : T.accent700,
                      width: 1,
                    ),
                    borderRadius: T.rMd,
                  ),
                  child: Text(
                    _digits[i],
                    style: Type.inlineValueLg.copyWith(fontSize: 26),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Resend in 0:${a.resendSeconds}', style: Type.rowSecondary),
            const Spacer(),
            InlineAction(
              'Wrong address?',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Nothing arrived? Check spam, and check the address above for a typo. '
          'We only ever send you a code — never a link that signs you in.',
          style: Type.footnote,
        ),
        const SizedBox(height: 16),
        // Fills the cells so the flow is walkable without a mail round-trip.
        GhostButton(
          'Paste the code (demo)',
          color: T.neutral700,
          onPressed: () => setState(() {
            for (var i = 0; i < 6; i++) {
              _digits[i] = '482619'[i];
            }
          }),
        ),
      ],
    );
  }
}

/// G4 — forgot password. The response is identical whether or not the address
/// has an account: telling the difference would leak who our users are.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Screen(
    gutter: T.gutterWide,
    backLabel: 'Sign in',
    onBack: () => Navigator.of(context).pop(),
    footer: ScreenFooter(
      gutter: T.gutterWide,
      children: [
        PrimaryButton(
          _sent ? 'Enter the code' : 'Send reset code',
          onPressed: () => _sent
              ? Navigator.of(context).push(_route(const ResetPasswordScreen()))
              : setState(() => _sent = true),
        ),
      ],
    ),
    children: [
      Text('Reset your password', style: Type.onboardingHeadline),
      const SizedBox(height: 12),
      Text(
        "Type the email you signed up with and we'll send you a reset code.",
        style: Type.body16Muted,
      ),
      const SizedBox(height: 22),
      Field(
        label: 'Email',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
      ),
      if (_sent) ...[
        const SizedBox(height: 16),
        const NoteBlock(
          "If that address has an account, a code is on its way. We don't say "
          'which addresses are registered — that would leak who our users are.',
        ),
      ],
      const SizedBox(height: 22),
      const NumberedFact(1, 'We email you a six-digit code'),
      const NumberedFact(2, 'You choose a new password in the app'),
      const NumberedFact(3, 'Every other device is signed out'),
      const SizedBox(height: 6),
      Text(
        'Your car data lives on this iPhone — resetting a password never '
        'touches it.',
        style: Type.footnote,
      ),
    ],
  );
}

/// G5 — choose a new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pw.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.read<AccountProvider>();
    final score = AccountProvider.strengthOf(_pw.text);
    final matches = _pw.text.isNotEmpty && _pw.text == _confirm.text;

    return Screen(
      gutter: T.gutterWide,
      backLabel: 'Back',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        gutter: T.gutterWide,
        children: [
          PrimaryButton(
            'Save new password',
            onPressed: matches && score >= 3
                ? () {
                    a.signIn();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                : null,
          ),
        ],
      ),
      children: [
        Text('Choose a new password', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text('Code accepted for ${a.email}.', style: Type.body16Muted),
        const SizedBox(height: 22),
        Field(label: 'New password', controller: _pw, obscure: true),
        if (_pw.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          _StrengthMeter(score: score),
        ],
        const SizedBox(height: 16),
        Field(
          label: 'Confirm new password',
          controller: _confirm,
          obscure: true,
        ),
        if (_confirm.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          _RuleRow(label: 'Both entries match', met: matches),
        ],
        const SizedBox(height: 12),
        for (final r in AccountProvider.passwordRules)
          _RuleRow(label: r.rule, met: r.test(_pw.text)),
        _RuleRow(
          label: 'Not one of your last three passwords',
          met: score >= 3,
        ),
        const SizedBox(height: 16),
        Text(
          'Saving this signs you out on your other devices. Nothing stored on '
          'this iPhone is affected.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

/// G6 — finish profile. All optional; it only changes what the user sees.
class FinishProfileScreen extends StatefulWidget {
  const FinishProfileScreen({super.key});

  @override
  State<FinishProfileScreen> createState() => _FinishProfileScreenState();
}

class _FinishProfileScreenState extends State<FinishProfileScreen> {
  final _name = TextEditingController(text: 'Muzaffar Ali');
  bool _sync = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AccountProvider>();
    final s = context.watch<SettingsProvider>();
    final e = context.watch<EntitlementProvider>();

    return Screen(
      gutter: T.gutterWide,
      footer: ScreenFooter(
        gutter: T.gutterWide,
        children: [
          PrimaryButton(
            'Save and open Torque',
            onPressed: () {
              a.setDisplayName(_name.text);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InlineAction(
            'Skip',
            color: T.neutral700,
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
        Text('Finish your profile', style: Type.onboardingHeadline),
        const SizedBox(height: 12),
        Text(
          'All optional. It only changes what you see in the app.',
          style: Type.body16Muted,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _Avatar(initials: a.initials, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InlineAction(
                    'Add a photo',
                    onPressed: () => notImplementedHere(
                      context,
                      'Photos stay on this iPhone, downscaled to 800 px.',
                    ),
                  ),
                  Text(
                    'Stays on your device, downscaled to 800 px.',
                    style: Type.footnote,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Field(label: 'Display name', controller: _name),
        const SectionHeading('Measurements'),
        AppListRow(
          title: 'Distance',
          trailing: Segmented(
            options: const ['km', 'mi'],
            selected: s.distance.index,
            onSelect: (i) => s.setDistance(DistanceUnit.values[i]),
          ),
        ),
        AppListRow(
          title: 'Temperature',
          trailing: Segmented(
            options: const ['°C', '°F'],
            selected: s.temperature.index,
            onSelect: (i) => s.setTemperature(TemperatureUnit.values[i]),
          ),
        ),
        AppListRow(
          title: 'Currency',
          value: s.currency,
          chevron: true,
          onTap: () => notImplementedHere(
            context,
            'Pick the currency your receipts are in.',
          ),
        ),
        const SizedBox(height: 8),
        AppListRow(
          title: 'Sync my garage to iCloud',
          subtitle: 'Your private database.',
          trailing: e.isPro
              ? AppSwitch(
                  value: _sync,
                  onChanged: (v) => setState(() => _sync = v),
                )
              : const Badge('PRO'),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.size = 56});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => Blueprint(
    corners: false,
    width: size,
    height: size,
    fill: T.accent700,
    child: Center(
      child: Text(
        initials,
        style: Type.inlineValueLg.copyWith(
          color: T.neutral100,
          fontSize: size * 0.36,
        ),
      ),
    ),
  );
}

/// G7 — profile. Signing out leaves everything on the device, and the screen
/// closes by saying so.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AccountProvider>();
    final e = context.watch<EntitlementProvider>();

    return Screen(
      backLabel: 'Settings',
      onBack: () => Navigator.of(context).pop(),
      title: 'Profile',
      titleTrailing: InlineAction(
        'Edit',
        onPressed: () => notImplementedHere(
          context,
          'Profile editing lands with the next Account pass.',
        ),
      ),
      children: [
        Row(
          children: [
            _Avatar(initials: a.initials, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.displayName, style: Type.cardTitleLg),
                  const SizedBox(height: 4),
                  Text(a.email, style: Type.rowSecondary),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (a.verified)
                        const TelltaleChip('Verified', tone: Tone.pass),
                      Badge(e.isPro ? 'Pro' : 'Free with ads'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TriStat([
          (value: '${a.vehicleCount}', label: 'Vehicle', tone: Tone.ink),
          (value: '${a.recordCount}', label: 'Records', tone: Tone.ink),
          (value: '${a.scanCount}', label: 'Scans', tone: Tone.ink),
        ]),
        const SectionHeading('Sync'),
        AppListRow(
          title: 'iCloud sync',
          value: e.isPro ? 'On' : 'Paused · Pro',
          chevron: true,
          onTap: () =>
              notImplementedHere(context, 'iCloud sync is a Pro feature.'),
        ),
        AppListRow(title: 'iPhone 15 Pro', subtitle: 'This device'),
        AppListRow(title: 'iPhone 11', subtitle: '3 days ago'),
        const SectionHeading('Account'),
        AppListRow(
          title: 'Account settings',
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const AccountSettingsScreen())),
        ),
        if (!e.isPro)
          AppListRow(
            title: 'Remove ads — go Pro',
            chevron: true,
            onTap: () => openPaywall(context),
          ),
        AppListRow(
          title: 'Sign out',
          titleStyle: Type.rowPrimary.copyWith(color: T.fault),
          onTap: () {
            a.signOut();
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Signing out leaves everything on this iPhone. Your garage, codes and '
          'receipts are local first, always.',
          style: Type.footnote,
        ),
      ],
    );
  }
}

/// G8 — account settings, including in-app account deletion, which App Store
/// Guideline 5.1.1(v) requires and which many apps hide behind support email.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AccountProvider>();
    final s = context.watch<SettingsProvider>();

    return Screen(
      title: 'Account settings',
      backLabel: 'Profile',
      onBack: () => Navigator.of(context).pop(),
      children: [
        const SectionHeading('Sign-in', topPadding: 4),
        AppListRow(
          title: 'Email',
          value: a.email,
          chevron: true,
          onTap: () => notImplementedHere(
            context,
            'Changing your email sends a code to the new address.',
          ),
        ),
        AppListRow(
          title: 'Password',
          value: 'Changed 2 Sep',
          chevron: true,
          onTap: () => notImplementedHere(
            context,
            'Changing a password re-authenticates through iOS.',
          ),
        ),
        AppListRow(
          title: 'Sign in with Apple',
          value: 'Not linked',
          chevron: true,
          onTap: () => notImplementedHere(
            context,
            'Sign in with Apple is handled by iOS.',
          ),
        ),
        AppListRow(
          title: 'Two-step verification',
          chevron: true,
          onTap: () => notImplementedHere(
            context,
            'Two-step verification is set up on the web.',
          ),
        ),
        const SectionHeading('Privacy'),
        AppListRow(
          title: 'Personalised ads',
          subtitle: 'Asks iOS for tracking permission',
          trailing: AppSwitch(
            value: s.personalisedAds,
            onChanged: s.setPersonalisedAds,
          ),
        ),
        AppListRow(
          title: 'Signed-in devices',
          value: '${a.signedInDevices}',
          chevron: true,
          onTap: () => notImplementedHere(
            context,
            'Opens the Privacy Policy in Safari.',
          ),
        ),
        AppListRow(
          title: 'Export everything as JSON',
          chevron: true,
          onTap: () => notImplementedHere(context, 'Copied your data as JSON.'),
        ),
        const SectionHeading('Danger zone'),
        AppListRow(
          title: 'Delete my account',
          titleStyle: Type.rowPrimary.copyWith(color: T.fault),
          chevron: true,
          onTap: () =>
              Navigator.of(context).push(_route(const DeleteAccountScreen())),
        ),
        const SizedBox(height: 14),
        Text(
          'Deleting the account removes your email and sync data from our server '
          'within 30 days. Your garage stays on this iPhone unless you also tap '
          'Delete all data.',
          style: Type.footnote,
        ),
        const SizedBox(height: 16),
        GhostButton(
          'Sign out',
          color: T.fault,
          onPressed: () {
            a.signOut();
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ],
    );
  }
}

/// M1 — delete account. Type-to-confirm, and four facts that answer the
/// questions a user actually has at this moment.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  static const _facts = [
    'Your email and any synced copies are removed from our server within 30 days',
    "You'll be signed out on every device",
    'Your garage stays on this iPhone. Vehicles, service records and snapshots '
        "are local — deleting the account doesn't touch them",
    'Pro stays active — it belongs to your Apple ID, not to this account',
  ];

  @override
  Widget build(BuildContext context) {
    final a = context.read<AccountProvider>();
    final ready = _confirm.text.trim() == 'DELETE';

    return Screen(
      title: 'Delete your account?',
      backLabel: 'Account settings',
      onBack: () => Navigator.of(context).pop(),
      footer: ScreenFooter(
        children: [
          DestructiveButton(
            'Delete my account',
            enabled: ready,
            onPressed: () {
              a.deleteAccount();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          const SizedBox(height: 4),
          GhostButton(
            'Cancel',
            color: T.neutral700,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      children: [
        for (final f in _facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icn(Lu.triangleAlert, size: 15, color: T.cautionText),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(f, style: Type.body15)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Field(
          label: 'Type DELETE to confirm',
          controller: _confirm,
          hint: 'DELETE',
        ),
      ],
    );
  }
}
