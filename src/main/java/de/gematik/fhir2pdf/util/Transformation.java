package de.gematik.fhir2pdf.util;

import java.nio.file.Path;
import org.verapdf.pdfa.results.ValidationResult;

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

/**
 * The outcome of turning one health record into a PDF and checking it.
 *
 * @param input the processed health record, as file path or classpath resource name
 * @param output the generated PDF, or {@code null} if the transformation failed
 * @param validationResult the archiving check result, or {@code null} if it failed
 */
public record Transformation(String input, Path output, ValidationResult validationResult) {

  /**
   * Tells whether the PDF meets the archiving standard.
   *
   * @return {@code true} if a validation result exists and is compliant
   */
  public boolean isCompliant() {
    return validationResult != null && validationResult.isCompliant();
  }
}
