package de.gematik.fhir2pdf.validator;

/*-
 * #%L
 * fhir2pdf-generator
 * %%
 * Copyright (C) 2026 gematik GmbH
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * *******
 *
 * For additional notes and disclaimer from gematik and in case of changes
 * by gematik, find details in the "Readme" file.
 * #L%
 */

import de.gematik.fhir2pdf.util.Util;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import lombok.SneakyThrows;
import lombok.experimental.UtilityClass;
import lombok.extern.slf4j.Slf4j;
import org.verapdf.gf.foundry.VeraGreenfieldFoundryProvider;
import org.verapdf.pdfa.Foundries;
import org.verapdf.pdfa.flavours.PDFAFlavour;
import org.verapdf.pdfa.results.ValidationResult;

/** Checks whether a PDF document meets the standard for long-term archiving. */

/** Advised to read README.md. */
@Slf4j
@UtilityClass
public class PdfValidator {

  static {
    VeraGreenfieldFoundryProvider.initialise();
  }

  private final PDFAFlavour DEFAULT_PDF_FLAVOUR = PDFAFlavour.PDFA_2_B;

  /**
   * Checks a PDF against the default archiving format.
   *
   * @param path the PDF file
   * @return the result for PDF/A-2b, or {@code null} if the file could not be validated
   */
  public ValidationResult validate(Path path) {
    return validate(path, DEFAULT_PDF_FLAVOUR);
  }

  /**
   * Checks a PDF against a chosen archiving format and logs every violated rule.
   *
   * @param pdfPath the PDF file
   * @param flavour the PDF/A flavour to validate against
   * @return the validation result, or {@code null} if the file could not be validated
   */
  @SneakyThrows
  public ValidationResult validate(Path pdfPath, PDFAFlavour flavour) {
    try (var inputStream = Files.newInputStream(pdfPath);
        var veraPDFFoundry = Foundries.defaultInstance();
        var parser = veraPDFFoundry.createParser(inputStream, flavour);
        var validator = veraPDFFoundry.createValidator(List.of(flavour))) {

      var validationResult = validator.validate(parser);
      if (validationResult.isCompliant()) {
        log.info("{} compliant:\t{}", Util.asString(flavour), pdfPath);
      } else {
        log.error("Not {} compliant:\t{}", Util.asString(flavour), pdfPath);
        validationResult.getTestAssertions().forEach(rule -> log.error("{}", rule));
      }
      return validationResult;
    } catch (Exception e) {
      log.error("Error validating PDF: {}", pdfPath, e);
      return null;
    }
  }
}
