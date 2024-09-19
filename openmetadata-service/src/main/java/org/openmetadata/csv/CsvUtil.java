/*
 *  Copyright 2021 Collate
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

package org.openmetadata.csv;

import static org.openmetadata.common.utils.CommonUtil.listOf;
import static org.openmetadata.common.utils.CommonUtil.listOrEmpty;
import static org.openmetadata.common.utils.CommonUtil.nullOrEmpty;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVFormat.Builder;
import org.apache.commons.csv.CSVPrinter;
import org.apache.commons.csv.CSVRecord;
import org.openmetadata.schema.type.EntityReference;
import org.openmetadata.schema.type.TagLabel;
import org.openmetadata.schema.type.csv.CsvFile;
import org.openmetadata.schema.type.csv.CsvHeader;

public final class CsvUtil {
  public static final String SEPARATOR = ",";
  public static final String FIELD_SEPARATOR = ";";

  public static final String ENTITY_TYPE_SEPARATOR = ":";
  public static final String LINE_SEPARATOR = "\r\n";

  public static final String INTERNAL_ARRAY_SEPARATOR = "|";

  private CsvUtil() {
    // Utility class hides the constructor
  }

  public static String formatCsv(CsvFile csvFile) throws IOException {
    // CSV file is generated by the backend and the data exported is expected to be correct. Hence,
    // no validation
    StringWriter writer = new StringWriter();
    List<String> headers = getHeaders(csvFile.getHeaders());
    CSVFormat csvFormat =
        Builder.create(CSVFormat.DEFAULT).setHeader(headers.toArray(new String[0])).build();
    try (CSVPrinter printer = new CSVPrinter(writer, csvFormat)) {
      for (List<String> csvRecord : listOrEmpty(csvFile.getRecords())) {
        printer.printRecord(csvRecord);
      }
    }
    return writer.toString();
  }

  /** Get headers from CsvHeaders */
  public static List<String> getHeaders(List<CsvHeader> csvHeaders) {
    List<String> headers = new ArrayList<>();
    for (CsvHeader header : csvHeaders) {
      String headerString = header.getName();
      if (Boolean.TRUE.equals(header.getRequired()))
        headerString = String.format("%s*", header.getName());
      headers.add(headerString);
    }
    return headers;
  }

  public static String recordToString(CSVRecord csvRecord) {
    return recordToString(csvRecord.toList());
  }

  public static String recordToString(List<String> fields) {
    return nullOrEmpty(fields)
        ? ""
        : fields.stream().map(CsvUtil::quoteCsvField).collect(Collectors.joining(SEPARATOR));
  }

  public static String recordToString(String[] fields) {
    return recordToString(Arrays.asList(fields));
  }

  public static List<String> fieldToStrings(String field) {
    // Split a field that contains multiple strings separated by FIELD_SEPARATOR
    return field == null || field.isBlank() ? null : listOf(field.split(FIELD_SEPARATOR));
  }

  public static List<String> fieldToEntities(String field) {
    // Split a field that contains multiple strings separated by FIELD_SEPARATOR
    return field == null ? null : listOf(field.split(ENTITY_TYPE_SEPARATOR));
  }

  public static List<String> fieldToInternalArray(String field) {
    // Split a fieldValue that contains multiple elements of an array separated by
    // INTERNAL_ARRAY_SEPARATOR
    if (field == null || field.isBlank()) {
      return Collections.emptyList();
    }
    return listOf(field.split(Pattern.quote(INTERNAL_ARRAY_SEPARATOR)));
  }

  /**
   * Parses a field containing key-value pairs separated by semicolons, correctly handling quotes.
   * Each key-value pair may also be enclosed in quotes, especially if it contains delimiter like (SEPARATOR , FIELD_SEPARATOR).
   *
   * Input Example:
   * "key1:value1;key2:value2;\"key3:value;with;semicolon\""
   * Output: ["key1:value1", "key2:value2", "key3:value;with;semicolon"]
   *
   * @param field The input string with key-value pairs.
   * @return A list of key-value pairs, handling quotes and semicolons correctly.
   */
  public static List<String> fieldToExtensionStrings(String field) {
    if (field == null || field.isBlank()) {
      return List.of();
    }

    List<String> result = new ArrayList<>();
    StringBuilder currentField = new StringBuilder();
    // Track whether we are inside quotes
    boolean inQuotes = false;

    // Iterate through each character in the field
    for (int i = 0; i < field.length(); i++) {
      char c = field.charAt(i);

      if (c == '"') {
        if (inQuotes && i + 1 < field.length() && field.charAt(i + 1) == '"') {
          // Handle escaped quote ("" -> ")
          currentField.append('"');
          i++;
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
          // Keep the quote as part of the field
          currentField.append(c);
        }
      } else if (c == FIELD_SEPARATOR.charAt(0) && !inQuotes) {
        // Add the field when semicolon is outside quotes
        addFieldToResult(result, currentField);
        // Reset buffer for next field
        currentField.setLength(0);
      } else {
        // Continue building the field
        currentField.append(c);
      }
    }

    // Add the last field
    addFieldToResult(result, currentField);

    return result;
  }

  /**
   * Adds the processed field to the result list, removing surrounding quotes if present.
   *
   * @param result List to hold parsed fields.
   * @param currentField The current field being processed.
   */
  private static void addFieldToResult(List<String> result, StringBuilder currentField) {
    String fieldStr = currentField.toString();

    // Remove surrounding quotes if field contains special characters and is quoted
    if ((fieldStr.contains(SEPARATOR) || fieldStr.contains(FIELD_SEPARATOR))
        && fieldStr.startsWith("\"")
        && fieldStr.endsWith("\"")) {
      fieldStr = fieldStr.substring(1, fieldStr.length() - 1);
    }

    result.add(fieldStr);
  }

  public static String quote(String field) {
    return String.format("\"%s\"", field);
  }

  /** Quote a CSV field made of multiple strings that has SEPARATOR or FIELD_SEPARATOR with " " */
  public static String quoteField(List<String> field) {
    return nullOrEmpty(field)
        ? ""
        : field.stream().map(CsvUtil::quoteCsvField).collect(Collectors.joining(FIELD_SEPARATOR));
  }

  public static void addField(List<String> csvRecord, Boolean field) {
    csvRecord.add(field == null ? "" : field.toString());
  }

  public static List<String> addField(List<String> csvRecord, String field) {
    csvRecord.add(field);
    return csvRecord;
  }

  public static List<String> addFieldList(List<String> csvRecord, List<String> field) {
    csvRecord.add(quoteField(field));
    return csvRecord;
  }

  public static List<String> addEntityReferences(
      List<String> csvRecord, List<EntityReference> refs) {
    csvRecord.add(
        nullOrEmpty(refs)
            ? null
            : refs.stream()
                .map(EntityReference::getFullyQualifiedName)
                .collect(Collectors.joining(FIELD_SEPARATOR)));
    return csvRecord;
  }

  public static List<String> addEntityReference(List<String> csvRecord, EntityReference ref) {
    csvRecord.add(nullOrEmpty(ref) ? null : ref.getFullyQualifiedName());
    return csvRecord;
  }

  public static List<String> addTagLabels(List<String> csvRecord, List<TagLabel> tags) {
    csvRecord.add(
        nullOrEmpty(tags)
            ? null
            : tags.stream()
                .filter(
                    tagLabel ->
                        tagLabel.getSource().equals(TagLabel.TagSource.CLASSIFICATION)
                            && !tagLabel.getTagFQN().split("\\.")[0].equals("Tier")
                            && !tagLabel.getLabelType().equals(TagLabel.LabelType.DERIVED))
                .map(TagLabel::getTagFQN)
                .collect(Collectors.joining(FIELD_SEPARATOR)));

    return csvRecord;
  }

  public static List<String> addGlossaryTerms(List<String> csvRecord, List<TagLabel> tags) {
    csvRecord.add(
        nullOrEmpty(tags)
            ? null
            : tags.stream()
                .filter(
                    tagLabel ->
                        tagLabel.getSource().equals(TagLabel.TagSource.GLOSSARY)
                            && !tagLabel.getTagFQN().split("\\.")[0].equals("Tier"))
                .map(TagLabel::getTagFQN)
                .collect(Collectors.joining(FIELD_SEPARATOR)));

    return csvRecord;
  }

  public static List<String> addTagTiers(List<String> csvRecord, List<TagLabel> tags) {
    csvRecord.add(
        nullOrEmpty(tags)
            ? null
            : tags.stream()
                .filter(
                    tagLabel ->
                        tagLabel.getSource().equals(TagLabel.TagSource.CLASSIFICATION)
                            && tagLabel.getTagFQN().split("\\.")[0].equals("Tier"))
                .map(TagLabel::getTagFQN)
                .collect(Collectors.joining(FIELD_SEPARATOR)));

    return csvRecord;
  }

  public static void addOwners(List<String> csvRecord, List<EntityReference> owners) {
    csvRecord.add(
        nullOrEmpty(owners)
            ? null
            : owners.stream()
                .map(owner -> (owner.getType() + ENTITY_TYPE_SEPARATOR + owner.getName()))
                .collect(Collectors.joining(FIELD_SEPARATOR)));
  }

  public static void addReviewers(List<String> csvRecord, List<EntityReference> reviewers) {
    csvRecord.add(
        nullOrEmpty(reviewers)
            ? null
            : reviewers.stream()
                .map(reviewer -> (reviewer.getType() + ENTITY_TYPE_SEPARATOR + reviewer.getName()))
                .collect(Collectors.joining(FIELD_SEPARATOR)));
  }

  private static String quoteCsvField(String str) {
    if (str.contains(SEPARATOR) || str.contains(FIELD_SEPARATOR)) {
      return quote(str);
    }
    return str;
  }

  public static void addExtension(List<String> csvRecord, Object extension) {
    if (extension == null) {
      csvRecord.add(null);
      return;
    }

    ObjectMapper objectMapper = new ObjectMapper();
    Map<String, Object> extensionMap = objectMapper.convertValue(extension, Map.class);

    String extensionString =
        extensionMap.entrySet().stream()
            .map(
                entry -> {
                  String key = entry.getKey();
                  Object value = entry.getValue();
                  return CsvUtil.quoteCsvField(key + ENTITY_TYPE_SEPARATOR + formatValue(value));
                })
            .collect(Collectors.joining(FIELD_SEPARATOR));

    csvRecord.add(extensionString);
  }

  private static String formatValue(Object value) {
    // Handle Map (e.g., entity reference or date interval)
    if (value instanceof Map) {
      return formatMapValue((Map<String, Object>) value);
    }

    // Handle List (e.g., Entity Reference List or multi-select Enum List)
    if (value instanceof List) {
      return formatListValue((List<?>) value);
    }

    // Fallback for simple types
    return value != null ? value.toString() : "";
  }

  private static String formatMapValue(Map<String, Object> valueMap) {
    if (isEntityReference(valueMap)) {
      return formatEntityReference(valueMap);
    } else if (isTimeInterval(valueMap)) {
      return formatTimeInterval(valueMap);
    }

    // If no specific format, return the raw map string
    return valueMap.toString();
  }

  private static String formatListValue(List<?> list) {
    if (list.isEmpty()) {
      return "";
    }

    if (list.get(0) instanceof Map) {
      // Handle a list of entity references or maps
      return list.stream()
          .map(item -> formatMapValue((Map<String, Object>) item))
          .collect(Collectors.joining(INTERNAL_ARRAY_SEPARATOR));
    } else {
      // Handle a simple list of strings or numbers
      return list.stream()
          .map(Object::toString)
          .collect(Collectors.joining(INTERNAL_ARRAY_SEPARATOR));
    }
  }

  private static boolean isEntityReference(Map<String, Object> valueMap) {
    return valueMap.containsKey("type") && valueMap.containsKey("fullyQualifiedName");
  }

  private static boolean isTimeInterval(Map<String, Object> valueMap) {
    return valueMap.containsKey("start") && valueMap.containsKey("end");
  }

  private static String formatEntityReference(Map<String, Object> valueMap) {
    return valueMap.get("type") + ENTITY_TYPE_SEPARATOR + valueMap.get("fullyQualifiedName");
  }

  private static String formatTimeInterval(Map<String, Object> valueMap) {
    return valueMap.get("start") + ENTITY_TYPE_SEPARATOR + valueMap.get("end");
  }
}
