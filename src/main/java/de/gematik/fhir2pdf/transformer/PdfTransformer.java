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

import de.gematik.fhir2pdf.util.Extension;
import de.gematik.fhir2pdf.util.ResourceUtil;
import de.gematik.fhir2pdf.util.Util;
import java.io.BufferedOutputStream;
import java.io.ByteArrayInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.OutputStream;
import java.net.URI;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.Callable;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.Result;
import javax.xml.transform.Source;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMResult;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.sax.SAXResult;
import javax.xml.transform.stream.StreamSource;
import lombok.SneakyThrows;
import lombok.experimental.UtilityClass;
import lombok.extern.slf4j.Slf4j;
import org.apache.fop.apps.Fop;
import org.apache.fop.apps.FopFactory;
import org.apache.xmlgraphics.util.MimeConstants;
import org.w3c.dom.Document;

/** Turns a health record into a PDF document that is suitable for long-term archiving. */
@Slf4j
@UtilityClass
public class PdfTransformer {

  private final String DEFAULT_STYLESHEET = "material/stylesheet/xml-to-pdf.xsl";
  private final String JSON_TO_XML_XSL = "material/stylesheet/fhir-json-to-xml.xsl";
  private final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");
  private final TransformerFactory TRANSFORMER_FACTORY = createTransformerFactory();
  private final FopFactory INSTANCE = createFopFactory();

  /**
   * Creates a PDF from a health record using the given layout.
   *
   * @param input the FHIR input file (XML or JSON)
   * @param stylesheet the XSL stylesheet defining the layout
   * @return the generated PDF, or {@code null} if {@code input} is {@code null} or the
   *     transformation failed
   */
  public Path transform(Path input, Path stylesheet) {
    return renderFile(input, () -> Content.ofFile(stylesheet));
  }

  /**
   * Creates a PDF from a health record using the standard layout.
   *
   * @param input the FHIR input file (XML or JSON)
   * @return the generated PDF, or {@code null} if {@code input} is {@code null} or the
   *     transformation failed
   */
  public Path transform(Path input) {
    return renderFile(input, () -> Content.ofResource(DEFAULT_STYLESHEET));
  }

  /**
   * Creates a PDF from a health record packaged inside the application, using the standard layout.
   *
   * @param inputResource the classpath-relative name of the FHIR input file (XML or JSON), e.g.
   *     {@code input/emp.xml}
   * @return the generated PDF, or {@code null} if the resource does not exist or the transformation
   *     failed
   */
  public Path transform(String inputResource) {
    return render(
        inputResource,
        () -> Content.ofResource(inputResource),
        () -> Content.ofResource(DEFAULT_STYLESHEET));
  }

  private Path renderFile(Path input, Callable<Content> stylesheetLoader) {
    if (input == null) {
      log.info("Transforming input:\t{}", (Object) null);
      log.warn("Input is null, skipping transformation.");
      return null;
    }
    return render(input.toString(), () -> Content.ofFile(input), stylesheetLoader);
  }

  private Path render(
      String label, Callable<Content> inputLoader, Callable<Content> stylesheetLoader) {
    log.info("Transforming input:\t{}", label);
    Content input;
    Content stylesheet;
    try {
      input = inputLoader.call();
      stylesheet = stylesheetLoader.call();
    } catch (Exception e) {
      log.error("Error reading input or stylesheet of: {}", label, e);
      return null;
    }

    var output = Util.createPdf(Util.createPdfName(Path.of(input.name())));
    try (var os = Files.newOutputStream(output);
        var pdf = new BufferedOutputStream(os)) {

      var extension = Extension.fromPath(Path.of(input.name()));
      var xmlSource =
          switch (extension) {
            case XML -> input.toSource();
            case JSON -> toXmlSource(input);
            default -> throw new IllegalArgumentException("Unsupported input type: " + extension);
          };
      applyStylesheet(xmlSource, stylesheet, new SAXResult(newFop(pdf).getDefaultHandler()));
    } catch (Exception e) {
      log.error("Error during transformation of input: {}", label, e);
      return null;
    }

    log.info("Generated PDF at:\t{}", output);
    return output;
  }

  @SneakyThrows
  private void applyStylesheet(Source xmlSource, Content stylesheet, Result target) {
    log.info("Applying XML stylesheet:\t{}", stylesheet.systemId());
    Extension.XSL.check(stylesheet.name());
    var transformer = TRANSFORMER_FACTORY.newTransformer(stylesheet.toSource());
    transformer.setParameter("creationDateTime", LocalDateTime.now().format(DATE_FORMAT));
    transformer.transform(xmlSource, target);
  }

  @SneakyThrows
  private Source toXmlSource(Content json) {
    Extension.JSON.check(json.name());
    var stylesheet = Content.ofResource(JSON_TO_XML_XSL);
    log.info("Applying JSON stylesheet:\t{}", stylesheet.systemId());
    var transformer = TRANSFORMER_FACTORY.newTransformer(stylesheet.toSource());
    transformer.setParameter("json", json.asString());
    var xml = new DOMResult();
    transformer.transform(new DOMSource(newEmptyDocument()), xml);
    return new DOMSource(xml.getNode());
  }

  /** A file that was read completely: from disk or from inside the application. */
  private static final class Content {
    private final String name;
    private final String systemId;
    private final byte[] bytes;

    private Content(String name, String systemId, byte[] bytes) {
      this.name = name;
      this.systemId = systemId;
      this.bytes = bytes;
    }

    String name() {
      return name;
    }

    String systemId() {
      return systemId;
    }

    static Content ofFile(Path path) throws IOException {
      return new Content(Util.getFilename(path), path.toUri().toString(), Files.readAllBytes(path));
    }

    static Content ofResource(String resource) throws IOException {
      var bytes = ResourceUtil.read(resource);
      if (bytes == null) {
        throw new FileNotFoundException("Resource not found: " + resource);
      }
      return new Content(
          resource.substring(resource.lastIndexOf('/') + 1),
          ResourceUtil.getUri(resource).toString(),
          bytes);
    }

    StreamSource toSource() {
      return new StreamSource(new ByteArrayInputStream(bytes), systemId);
    }

    String asString() throws CharacterCodingException {
      return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(bytes)).toString();
    }
  }

  @SneakyThrows
  private Document newEmptyDocument() {
    var factory = DocumentBuilderFactory.newInstance();
    factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
    factory.setXIncludeAware(false);
    factory.setExpandEntityReferences(false);
    return factory.newDocumentBuilder().newDocument();
  }

  @SneakyThrows
  private Fop newFop(OutputStream os) {
    return INSTANCE.newFop(MimeConstants.MIME_PDF, os);
  }

  @SneakyThrows
  private FopFactory createFopFactory() {
    var configBytes = FopConfigUtil.ofDefault().getBytes(StandardCharsets.UTF_8);
    try (var bais = new ByteArrayInputStream(configBytes)) {
      return FopFactory.newInstance(URI.create("file:///"), bais);
    }
  }

  @SneakyThrows
  private TransformerFactory createTransformerFactory() {
    var factory = TransformerFactory.newInstance();
    factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    return factory;
  }
}
