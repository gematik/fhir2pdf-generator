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
import java.io.ByteArrayInputStream;
import java.io.StringReader;
import java.io.StringWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.verapdf.pdfa.flavours.PDFAFlavour;

@Slf4j
class PdfTransformerTest {

  @Test
  void generatePdfFromXml() {
    var output = PdfTransformer.transform("input/emp.xml");
    assertThat(output).exists();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_2_B).isCompliant()).isTrue();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_4).isCompliant()).isFalse();
  }

  @Test
  void generatePdfFromJson() {
    var output = PdfTransformer.transform("input/emp.json");
    assertThat(output).exists();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_2_B).isCompliant()).isTrue();
  }

  @Test
  void generatePdfFromFile() {
    var output = PdfTransformer.transform(Path.of(ResourceUtil.getUri("input/emp.xml")));
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
              assertThat(transformation.input()).isNotBlank();
              assertThat(transformation.output()).exists();
              assertThat(transformation.isCompliant()).isTrue();
            });
  }

  @Test
  void transformationIsCompliantThrowsWithValidationResultNull() {
    var transformations =
        ResourceUtil.getAllInput().stream()
            .map(
                input -> {
                  var output = PdfTransformer.transform(input);
                  return new Transformation(input, output, null);
                })
            .toList();

    assertThat(transformations)
        .isNotEmpty()
        .allSatisfy(
            transformation -> {
              assertThat(transformation.input()).isNotBlank();
              assertThat(transformation.output()).exists();
              assertThat(transformation.isCompliant()).isFalse();
            });
  }

  @Test
  void xlsNotFoundThrows() {
    var input = Path.of(ResourceUtil.getUri("input/emp.xml"));
    assertThat(PdfTransformer.transform(input, Path.of("a/b/c.xsl"))).isNull();
  }

  @Test
  void inputNotFound() {
    assertThat(PdfTransformer.transform("a/b/c.xml")).isNull();
  }

  @Test
  void nullInput() {
    assertThat(PdfTransformer.transform((Path) null)).isNull();
  }

  @Test
  void jsonFromFile(@TempDir Path temp) throws Exception {
    var json = temp.resolve("emp.json");
    Files.write(json, ResourceUtil.read("input/emp.json"));

    var output = PdfTransformer.transform(json);

    assertThat(output).exists();
    assertThat(PdfValidator.validate(output, PDFAFlavour.PDFA_2_B).isCompliant()).isTrue();
  }

  @Test
  void jsonWithInvalidUtf8IsRejected(@TempDir Path temp) throws Exception {
    var json = temp.resolve("broken.json");
    Files.write(json, new byte[] {'{', (byte) 0xC3, (byte) 0x28, '}'});

    assertThat(PdfTransformer.transform(json)).isNull();
  }

  @Test
  void unsupportedInputTypeIsRejected(@TempDir Path temp) throws Exception {
    var pdf = temp.resolve("input.pdf");
    Files.writeString(pdf, "not a health record");

    assertThat(PdfTransformer.transform(pdf)).isNull();
  }

  @Test
  void stylesheetWithWrongExtensionIsRejected(@TempDir Path temp) throws Exception {
    var stylesheet = temp.resolve("layout.txt");
    Files.write(stylesheet, ResourceUtil.read("material/stylesheet/xml-to-pdf.xsl"));
    var input = Path.of(ResourceUtil.getUri("input/emp.xml"));

    assertThat(PdfTransformer.transform(input, stylesheet)).isNull();
  }

  @Test
  void customStylesheetFromFile(@TempDir Path temp) throws Exception {
    var stylesheet = temp.resolve("layout.xsl");
    Files.write(stylesheet, ResourceUtil.read("material/stylesheet/xml-to-pdf.xsl"));
    var input = Path.of(ResourceUtil.getUri("input/emp.xml"));

    assertThat(PdfTransformer.transform(input, stylesheet)).exists();
  }

  @Test
  void decimalDoseIsNotSplit() throws Exception {
    var xml = new String(ResourceUtil.read("input/emp.xml"), StandardCharsets.UTF_8);
    var doseStart = xml.indexOf("<doseQuantity>");
    var value = "<value value=\"1\"/>";
    var valueStart = xml.indexOf(value, doseStart);
    var modified =
        xml.substring(0, valueStart)
            + "<value value=\"0.75\"/>"
            + xml.substring(valueStart + value.length());

    var transformer =
        TransformerFactory.newInstance()
            .newTransformer(
                new StreamSource(
                    new ByteArrayInputStream(
                        ResourceUtil.read("material/stylesheet/xml-to-pdf.xsl"))));
    transformer.setParameter("creationDateTime", "23.11.2026 10:00");
    var fo = new StringWriter();
    transformer.transform(new StreamSource(new StringReader(modified)), new StreamResult(fo));

    assertThat(fo.toString()).containsPattern(">0,75</fo:block>").doesNotContain(">0,7</fo:block>");
  }
}
