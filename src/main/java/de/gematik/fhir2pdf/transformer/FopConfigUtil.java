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

import de.gematik.fhir2pdf.util.Util;
import java.util.List;
import java.util.stream.Collectors;
import lombok.experimental.UtilityClass;
import lombok.extern.slf4j.Slf4j;
import org.verapdf.pdfa.flavours.PDFAFlavour;

@Slf4j
@UtilityClass
class FopConfigUtil {
  private final PDFAFlavour DEFAULT_PDF_FLAVOUR = PDFAFlavour.PDFA_2_B;

  String ofDefault() {
    return of(DEFAULT_PDF_FLAVOUR, List.of(Font.REGULAR, Font.BOLD, Font.NARROW, Font.NARROW_BOLD));
  }

  String of(PDFAFlavour flavour, List<Font> fonts) {
    var flavourString = Util.asString(flavour);
    log.info(
        "Building FOP config for '{}' with fonts: {}",
        flavourString,
        fonts.stream().map(Font::getName).collect(Collectors.joining(", ")));

    var pdfModeTag =
        flavour == null ? "" : "<pdf-a-mode>%s</pdf-a-mode>%n".formatted(flavourString);

    var rendererBody = getRenderBodyAsString(fonts, pdfModeTag);
    return """
    <fop version="1.0">
      <renderers>
        <renderer mime="application/pdf">
    %s
        </renderer>
      </renderers>
    </fop>
    """
        .formatted(rendererBody);
  }

  private String getRenderBodyAsString(List<Font> fonts, String pdfModeTag) {
    var rendererBody = pdfModeTag + fonts(fonts);
    rendererBody = rendererBody.indent(6).stripTrailing();
    return rendererBody;
  }

  private String fonts(List<Font> fonts) {
    var fontBody =
        fonts.isEmpty()
            ? "<auto-detect/>"
            : fonts.stream().map(Font::getXml).collect(Collectors.joining("%n".formatted()));
    return """
    <fonts>
    %s
    </fonts>
    """
        .formatted(fontBody.indent(2).stripTrailing());
  }
}
