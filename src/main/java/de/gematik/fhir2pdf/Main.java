package de.gematik.fhir2pdf;

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

import de.gematik.fhir2pdf.transformer.PdfTransformer;
import de.gematik.fhir2pdf.util.ResourceUtil;
import de.gematik.fhir2pdf.util.Transformation;
import de.gematik.fhir2pdf.validator.PdfValidator;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.event.Level;

/** Creates a PDF for each bundled health record and checks that it is suitable for archiving. */
@Slf4j
public class Main {

  static void main(String[] args) {
    if (args.length > 0) {
      log.info("Application arguments: {}", String.join(" ", args));
      log.warn("Arguments are ignored. All input files will be processed.");
    }
    System.exit(processBundledFiles());
  }

  /**
   * Transforms and validates all bundled input files and logs the result per file.
   *
   * @return {@code 1} if an unexpected exception occurred, otherwise {@code 0}
   */
  static int processBundledFiles() {
    try {
      var allInput = ResourceUtil.getAllInput();
      if (allInput.isEmpty()) {
        log.warn("No input files found in the bundled resources.");
        return 0;
      }
      allInput.forEach(
          input -> {
            var pdf = PdfTransformer.transform(input);
            var transformation = new Transformation(input, pdf, PdfValidator.validate(pdf));

            if (transformation.output() == null) {
              log.warn("Transformation failed for input: {}", transformation.input());
              return;
            }

            if (transformation.validationResult() == null) {
              log.warn("Validation failed for PDF: {}", transformation.output());
              return;
            }

            log.makeLoggingEventBuilder(transformation.isCompliant() ? Level.INFO : Level.ERROR)
                .setMessage("{}\t>>> >>>\t{}\t>>> >>>\t{}")
                .addArgument(transformation.input())
                .addArgument(transformation.output())
                .addArgument(transformation.isCompliant() ? "Compliant!" : "Not compliant!")
                .log();
          });
      return 0;
    } catch (Exception e) {
      log.error("Error during processing of bundled files", e);
      return 1;
    }
  }
}
