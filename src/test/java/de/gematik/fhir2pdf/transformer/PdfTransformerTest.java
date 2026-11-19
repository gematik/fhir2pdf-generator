package de.gematik.fhir2pdf.transformer;

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

import static org.assertj.core.api.Assertions.assertThat;

import de.gematik.fhir2pdf.util.ResourceUtil;
import de.gematik.fhir2pdf.util.Transformation;
import de.gematik.fhir2pdf.validator.PdfValidator;
import java.nio.file.Path;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.verapdf.pdfa.flavours.PDFAFlavour;

@Slf4j
class PdfTransformerTest {

  @Test
  void generatePdfFromXml() {
    var output = PdfTransformer.transform(ResourceUtil.get("input/emp.xml"));
    assertThat(output).exists();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_2_B).isCompliant()).isTrue();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_4).isCompliant()).isFalse();
  }

  @Test
  void generatePdfFromJson() {
    var output = PdfTransformer.transform(ResourceUtil.get("input/emp.json"));
    assertThat(output).exists();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_2_B).isCompliant()).isTrue();
  }

  @Test
  void generatePdfFromAll() {
    var transformations =
        ResourceUtil.getAllInput().stream()
            .map(
                input -> {
                  var output = PdfTransformer.transform(input);
                  return new Transformation(input, output, PdfValidator.validate(output));
                })
            .toList();

    assertThat(transformations)
        .isNotEmpty()
        .allSatisfy(
            transformation -> {
              assertThat(transformation.input()).exists();
              assertThat(transformation.output()).exists();
              assertThat(transformation.isCompliant()).isTrue();
            });
  }

  @Test
  void xlsNotFoundThrows() {
    assertThat(PdfTransformer.transform(ResourceUtil.get("input/emp.xml"), Path.of("a/b/c.xsl")))
        .isNull();
  }

  @Test
  void inputNotFound() {
    assertThat(PdfTransformer.transform(ResourceUtil.get("a/b/c.xml"))).isNull();
  }
}
