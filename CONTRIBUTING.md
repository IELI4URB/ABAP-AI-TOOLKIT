# Contributing

Thank you for contributing to the ABAP Development AI Toolkit.

## Before You Start

- Open an issue or align with the maintainers before making a substantial change.
- Keep changes focused and preserve the toolkit's existing skill-group and agent ownership boundaries.
- Do not include SAP credentials, customer data, personal data, secrets, internal system details, or generated logs.
- Follow SAP's guidance and your organization's policies for AI-assisted contributions.

## Development

1. Create a branch from the latest `main`.
2. Make the smallest coherent change.
3. Run the repository validation:

   ```bash
   python validate_pack.py
   ```

4. Review `git diff --check` and ensure documentation links resolve.
5. Submit a pull request describing the scope, validation evidence, and any residual risks.

## Developer Certificate of Origin

All commits must be signed off under the [Developer Certificate of Origin](https://developercertificate.org/). A sign-off certifies that you have the right to submit the contribution under this repository's license.

Create a signed-off commit with:

```bash
git commit --signoff
```

The commit message must contain a line in this form:

```text
Signed-off-by: Your Name <your.email@example.com>
```

## AI-Assisted Contributions

Contributors remain responsible for all submitted content, including AI-assisted changes. Verify technical claims, licenses, security implications, generated code, and test results before submission. Identify material AI assistance in the pull request when required by SAP or organizational policy.