# eMP Offline Rendering (PoC)

A reference implementation of using XSL to render a FHIR R4 medication plan (eMP) bundle as a **PDF/A-2b**
document, as specified by the
[
`$get-medication-plan` operation of the ePA Medication Service (IG v1.4.0-ballot.1)](https://gemspec.gematik.de/ig/fhir/epa-medication/1.4.0-ballot.1/de/op-get-medication-plan.html)
and
its [render API](https://gemspec.gematik.de/ig/fhir/epa-medication/1.4.0-ballot.1/de/render-api-emp.html#IG-MED59609CUM).

> ⚠️⚠️⚠️
> **Note:** This project is a proof of concept and is **not intended for use in a production environment**.

## What is in it

- **`xml-to-pdf.xsl`** – the reference stylesheet (XSLT 3.0, FHIR XML → XSL-FO). It defines the layout and is the part
  vendors are meant to reuse.
- **`fhir-json-to-xml.xsl`** – converts FHIR JSON to FHIR XML (HL7 JSON-to-XML rules), so one stylesheet serves both
  input
  formats.
- **A small Java pipeline** (Saxon-HE → Apache FOP → veraPDF) that wires everything together and checks the PDF/A-2b
  conformance of the result.

```
FHIR JSON ──fhir-json-to-xml.xsl──┐
                                  ├─► FHIR XML ──xml-to-pdf.xsl──► XSL-FO ──Apache FOP──► PDF/A-2b ──► veraPDF
FHIR XML ─────────────────────────┘      (Saxon-HE)
```

## Quick start

### Prerequisites

| Tool  | Version      |
|-------|--------------|
| JDK   | **25**       |
| Maven | 3.9 or newer |

The stylesheets themselves do not depend on the JDK version.

### Build and run

```
mvn clean package
java -jar target/fhir2pdf-generator-1.0.0-SNAPSHOT.jar
```

The packaged .JAR is self-contained and bundles the sample inputs. Every file in
`src/main/resources/input/` (`.xml` or `.json`, FHIR R4 bundle containing the medication plan) is rendered to
`target/generated-pdf/<name>.pdf` and validated with veraPDF.

`mvn clean verify` runs the same pipeline.

## Limitations

**The stylesheet does not validate its input.** It assumes a well-formed FHIR R4 medication plan bundle and renders
what it finds. The only check is the filter required by IG-MED18735RJF-02: `MedicationRequest.status = 'active'`
(entries with any other status are skipped, and if none remain, the PDF has an empty table).

Missing or malformed data results in empty fields instead of an error.
The generated PDF is validated for PDF/A-2b conformance only, not for the content.

## Repository layout

| Path                                       | Purpose                   |
|--------------------------------------------|---------------------------|
| `input/`                                   | Input files (JSON or XML) |
| `material/stylesheet/fhir-json-to-xml.xsl` | FHIR JSON → FHIR XML      |
| `material/stylesheet/xml-to-pdf.xsl`       | FHIR XML → XSL-FO         |
| `material/ttf/`                            | Embedded fonts            |
| `transformer/`                             | Saxon → FOP pipeline      |
| `validator/`                               | veraPDF validation        |
| `util/`                                    | Shared helpers            |

Paths under `material/` and `input/` are relative to `src/main/resources/`.

## Contributing

Code style is enforced by Spotless (google-java-format): `mvn spotless:apply`.

See [CONTRIBUTING](.github/CONTRIBUTING.md) for how to contribute and [SECURITY](.github/SECURITY.md) for how to
report vulnerabilities. Please also read our [Code of Conduct](.github/CODE_OF_CONDUCT.md).

## Issues

To open an issue for this repository, please use the gematik service desk:
https://service.gematik.de/servicedesk/customer/portal/26

## License

Copyright 2026 gematik GmbH

Apache License, Version 2.0

See the [LICENSE](./LICENSE.md) for the specific language governing permissions and limitations under the License.

## Additional Notes and Disclaimer from gematik GmbH

1. Copyright notice: Each published work result is accompanied by an explicit statement of the license conditions for
   use. These are regularly typical conditions in connection with open source or free software. Programs
   described/provided/linked here are free software, unless otherwise stated.
2. Permission notice: Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
   associated documentation files (the "Software"), to deal in the Software without restriction, including without
   limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
   Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
    1. The copyright notice (Item 1) and the permission notice (Item 2) shall be included in all copies or substantial
       portions of the Software.
    2. The software is provided "as is" without warranty of any kind, either express or implied, including, but not
       limited to, the warranties of fitness for a particular purpose, merchantability, and/or non-infringement. The
       authors or copyright holders shall not be liable in any manner whatsoever for any damages or other claims arising
       from, out of or in connection with the software or the use or other dealings with the software, whether in an
       action of contract, tort, or otherwise.
    3. The software is the result of research and development activities, therefore not necessarily quality assured and
       without the character of a liable product. For this reason, gematik does not provide any support or other user
       assistance (unless otherwise stated in individual cases and without justification of a legal obligation).
       Furthermore, there is no claim to further development and adaptation of the results to a more current state of
       the art.
3. Gematik may remove published results temporarily or permanently from the place of publication at any time without
   prior notice or justification.
4. Parts of this software and - in isolated cases - content such as text or images may have been developed using the
   support of AI tools. They are subject to the same reviews, tests, and security checks as any other contribution. The
   functionality of the software itself is not based on AI decisions.
5. Please note: Parts of this code may have been generated using AI-supported technology. Please take this into account,
   especially when troubleshooting, for security analyses and possible adjustments.

## Contact

gematik GmbH: [OSPO@gematik.de](mailto:OSPO@gematik.de)
