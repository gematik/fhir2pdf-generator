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

import static org.assertj.core.api.AssertionsForClassTypes.assertThat;

import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Test;

@Slf4j
class FopConfigUtilTest {

  @Test
  void happyPath() {
    var configXml = FopConfigUtil.ofDefault();
    assertThat(configXml)
        .isEqualTo(
            """
            <fop version="1.0">
              <renderers>
                <renderer mime="application/pdf">
                  <pdf-a-mode>%s</pdf-a-mode>
                  <fonts>
                    <font embed-url="%s">
                      <font-triplet name="Liberation Sans" style="normal" weight="normal"/>
                    </font>
                    <font embed-url="%s">
                      <font-triplet name="Liberation Sans" style="normal" weight="bold"/>
                    </font>
                    <font embed-url="%s">
                      <font-triplet name="Liberation Sans Narrow" style="normal" weight="normal"/>
                    </font>
                    <font embed-url="%s">
                      <font-triplet name="Liberation Sans Narrow" style="normal" weight="bold"/>
                    </font>
                  </fonts>
                </renderer>
              </renderers>
            </fop>
            """
                .formatted(
                    "PDF/A-2b",
                    Font.REGULAR.getPath().toUri(),
                    Font.BOLD.getPath().toUri(),
                    Font.NARROW.getPath().toUri(),
                    Font.NARROW_BOLD.getPath().toUri()));
  }

  @Test
  void nullFlavour() {
    var configXml = FopConfigUtil.of(null, List.of(Font.REGULAR));
    assertThat(configXml)
        .doesNotContain("<pdf-a-mode>")
        .isEqualTo(
            """
            <fop version="1.0">
              <renderers>
                <renderer mime="application/pdf">
                  <fonts>
                    <font embed-url="%s">
                      <font-triplet name="Liberation Sans" style="normal" weight="normal"/>
                    </font>
                  </fonts>
                </renderer>
              </renderers>
            </fop>
            """
                .formatted(Font.REGULAR.getPath().toUri()));
  }

  @Test
  void nullFonts() {
    var configXml = FopConfigUtil.of(null, List.of());
    assertThat(configXml)
        .doesNotContain("<pdf-a-mode>")
        .isEqualTo(
            """
            <fop version="1.0">
              <renderers>
                <renderer mime="application/pdf">
                  <fonts>
                    <auto-detect/>
                  </fonts>
                </renderer>
              </renderers>
            </fop>
            """);
  }
}
