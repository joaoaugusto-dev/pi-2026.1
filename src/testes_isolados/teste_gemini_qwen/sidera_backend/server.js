const crypto = require('crypto');
const cors = require('cors');
const express = require('express');
const fetch = require('node-fetch');
const multer = require('multer');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

const upload = multer({ storage: multer.memoryStorage() });
const INSPECTIONS = new Map();

const OLLAMA_URL = process.env.OLLAMA_URL || 'https://limit-calcium-told-explorer.trycloudflare.com';
const MODEL_NAME = process.env.MODEL_NAME || 'llava-phi3';
const STREAM_ENABLED = process.env.OLLAMA_STREAM !== 'false';
const INSPECTION_TTL_HOURS = Number(process.env.INSPECTION_TTL_HOURS || 24);
const ANALYSIS_ENSEMBLE_SIZE = Math.max(1, Number(process.env.ANALYSIS_ENSEMBLE_SIZE || 1));
const STRICT_MIN_CONFIDENCE = clamp(Number(process.env.STRICT_MIN_CONFIDENCE || 0.82), 0, 1);
const ENABLE_RECOVERY_PASS = process.env.ENABLE_RECOVERY_PASS !== 'false';
const ENABLE_REASONING_THEN_JSON = process.env.ENABLE_REASONING_THEN_JSON !== 'false';
const FINAL_JSON_START_MARKER = 'FINAL_JSON_START';
const FINAL_JSON_END_MARKER = 'FINAL_JSON_END';
const MODEL_FIRST_STRICT_MODE = process.env.MODEL_FIRST_STRICT_MODE === 'true';
const REJECT_INVALID_PLAN = process.env.REJECT_INVALID_PLAN !== 'false';
const CORE_REQUIRED_CLASSES = ['base'];
const FOCUS_CLASSES = ['base', 'height', 'thickness', 'hole', 'chamfer', 'bend', 'u_cutout'];
const KNOWN_STEP_CLASSES = ['base', 'height', 'thickness', 'hole', 'chamfer', 'bend', 'u_cutout', 'other'];
const KNOWN_ENTITY_SYMBOL_TYPES = [
  'linear',
  'diameter',
  'radius',
  'angle',
  'chamfer',
  'bend_directive',
  'gdt',
  'thread',
  'note',
  'unknown',
];
const ENVELOPE_FOUNDATIONAL_CLASSES = ['base', 'height'];
const MIN_LEDGER_ENTITY_CONFIDENCE = clamp(Number(process.env.MIN_LEDGER_ENTITY_CONFIDENCE || 0.45), 0, 1);
const LEDGER_MAX_ENTITIES = Math.max(20, Number(process.env.LEDGER_MAX_ENTITIES || 180));
const LEDGER_RECALL_MIN_ENTITIES = Math.max(1, Number(process.env.LEDGER_RECALL_MIN_ENTITIES || 4));
const LEDGER_STRICT_MAPPING = process.env.LEDGER_STRICT_MAPPING !== 'false';
const STANDARD_THICKNESS_MM = [1.2, 1.5, 2.0, 2.25, 2.65, 3.0, 3.75, 4.25, 4.75, 6.3, 8.0, 9.5, 12.5];
const MANUAL_TECHNICAL_REFERENCE = Object.freeze({
  source_document: 'manual-tecnico.pdf',
  revision: '2019/2020',
  standards: ['ABNT/NBR 6355', 'NBR 14514', 'NBR 6591'],
  profile_families: ['perfil_u_simples', 'perfil_u_enrijecido', 'perfil_cartola', 'perfil_dobrado'],
  standard_thickness_mm: STANDARD_THICKNESS_MM,
  typical_lengths_mm: [3000, 6000],
});
const NOTE_VISUAL_LEGEND = Object.freeze({
  u_cutout: 'recorte tipo U',
  chamfer: 'chanfros Nx45',
  bend: 'dobras em linha de dobra',
  hole: 'furos com simbolo de diametro',
  base: 'cota principal de base/comprimento',
  height: 'cota vertical principal',
  thickness: 'espessura de chapa em perfil',
});

const TECHNICAL_DRAWING_READING_PROTOCOL = `
TECHNICAL DRAWING READING PROTOCOL (COMPACT AND STRICT):
- Read dimensions by view (top/profile/front/detail). Never mix views.
- Extract literals exactly as shown in the drawing (e.g., 55, 10x45, Ø12, R5, 9.50).
- Do not invent dimensions. If uncertain, keep the entity with lower confidence.
- Mandatory classification rules:
  * Nx45 => chamfer (linear mm), never bend.
  * Ø/⌀/diam/phi => hole.
  * R => radius/contour unless explicit circular-hole evidence exists.
  * Bend only when there is explicit physical bend evidence.
- Thickness must come from profile thickness dimensions when available (e.g., 9.50).
- Maximize coverage of visible measurable dimensions without duplicates.
`;

const LEDGER_EXTRACTION_PROMPT = `You are a technical drawing analyst.
${TECHNICAL_DRAWING_READING_PROTOCOL}

Return ONLY valid JSON containing the field entity_ledger.

Ledger objective:
1) Enumerate ALL visible measurable dimensions/symbols (linear, Ø, R, Nx45, thickness).
2) Create one entity per relevant literal.
3) If ambiguous, keep the entity with lower confidence instead of omitting it.

Schema:
{
  "entity_ledger": [
    {
      "id": "ENT_1",
      "literal": "55",
      "symbol_type": "linear|diameter|radius|angle|chamfer|bend_directive|gdt|thread|note|unknown",
      "feature_class": "base|height|thickness|hole|chamfer|bend|u_cutout|other",
      "primary_value": 55,
      "secondary_value": 0,
      "quantity": 1,
      "unit": "mm|deg|unknown",
      "view_hint": "top|profile|front|detail|isometric|unknown",
      "orientation_hint": "horizontal|vertical|auto|unknown",
      "confidence": 0.8,
      "evidence": "short rationale"
    }
  ]
}

Additional rules:
- For chamfer Nx45: primary_value=N and secondary_value=45.
- For Ø10 (4x): quantity=4.
- Do not return the inspection plan at this stage.`;

const BASE_PROMPT = `You are a Senior Metrology and Technical Drawing Analysis Specialist.
${TECHNICAL_DRAWING_READING_PROTOCOL}

Return ONLY valid JSON for an inspection plan.

Mandatory rules:
1) Every step must use a visible literal source_callout.
2) If entity_ledger is provided, use it as the primary source.
3) Do not use placeholders (e.g., "string", "part name").
4) expected_value must match the dimension literal (no unjustified rounding).
5) analysis_type/unit mapping: aruco_2d -> mm, angle_profile -> deg.
6) measurement_mode mapping: hole_diameter for holes, slot_width for U-cutouts, outer_span for generic linear dimensions.
7) Do not duplicate the same dimension/class pair.

Minimal schema:
{
  "geometry_check": {
    "is_flat_plate": true,
    "has_physical_bends_or_folds": false,
    "has_circular_holes": false
  },
  "part_name": "...",
  "unit": "mm",
  "notes": "...",
  "entity_ledger": [],
  "steps": [
    {
      "id": "STEP_1",
      "title": "...",
      "instruction": "...",
      "required_view": "top|profile|front|detail|isometric",
      "analysis_type": "aruco_2d|angle_profile",
      "measurement_mode": "outer_span|hole_diameter|slot_width|auto",
      "axis_preference": "auto|horizontal|vertical",
      "target_hint": "...",
      "source_callout": "literal",
      "expected_value": 0,
      "tolerance": 0.2,
      "unit": "mm|deg",
      "requires_all_markers": true,
      "capture_checklist": []
    }
  ]
}`;

function logStructured(event, payload = {}) {
  console.log(
    JSON.stringify({
      ts: new Date().toISOString(),
      event,
      ...payload,
    }),
  );
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function nowIso() {
  return new Date().toISOString();
}

function generateInspectionId() {
  return `insp_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
}

class PlanRejectedError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = 'PlanRejectedError';
    this.statusCode = 422;
    this.details = details;
  }
}

function cleanupInspectionStore() {
  const maxAgeMs = INSPECTION_TTL_HOURS * 60 * 60 * 1000;
  const cutoff = Date.now() - maxAgeMs;

  for (const [id, entry] of INSPECTIONS.entries()) {
    if (new Date(entry.createdAt).getTime() < cutoff) {
      INSPECTIONS.delete(id);
    }
  }
}

function normalizeString(value, fallback = '') {
  if (value === null || value === undefined) {
    return fallback;
  }
  const text = String(value).trim();
  return text || fallback;
}

function isTemplatePlaceholderText(value) {
  const text = normalizeString(value, '').toLowerCase().replace(/\s+/g, ' ').trim();
  if (!text) {
    return false;
  }

  if (/^\.{2,}$/.test(text)) {
    return true;
  }

  const asciiText = text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

  if (/^string(?:_[a-z0-9]+)?$/i.test(asciiText)) {
    return true;
  }

  return [
    'nome da peca',
    'topologia inferida',
    'source_callout',
    'source callout',
    'target_hint',
    'target hint',
    'titulo',
    'title',
    'instrucao',
    'instruction',
    'part name',
    'inferred topology',
    'callout',
    'n/a',
    'na',
  ].includes(asciiText);
}

function normalizePartName(rawName, fallback = 'Peca sem nome') {
  const value = normalizeString(rawName, '');
  if (!value || isTemplatePlaceholderText(value)) {
    return fallback;
  }
  return value;
}

function normalizePlanNotes(rawNotes, fallback = '') {
  const value = normalizeString(rawNotes, '');
  if (!value || isTemplatePlaceholderText(value)) {
    return fallback;
  }
  return value;
}

function normalizeNumber(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  const parsed = Number(String(value).replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeBool(value, fallback = false) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (value === null || value === undefined) {
    return fallback;
  }
  const normalized = String(value).trim().toLowerCase();
  if (['1', 'true', 'yes', 'sim'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no', 'nao'].includes(normalized)) {
    return false;
  }
  return fallback;
}

function normalizeView(rawView, fallback = 'top') {
  const normalized = normalizeString(rawView, fallback).toLowerCase();
  if (['top', 'profile', 'front', 'isometric', 'detail'].includes(normalized)) {
    return normalized;
  }
  return fallback;
}

function normalizeAxisPreference(rawAxis, fallback = 'auto') {
  const normalized = normalizeString(rawAxis, fallback).toLowerCase();
  if (['auto', 'horizontal', 'vertical', 'x', 'y'].includes(normalized)) {
    if (normalized === 'x') {
      return 'horizontal';
    }
    if (normalized === 'y') {
      return 'vertical';
    }
    return normalized;
  }
  return fallback;
}

function findDuplicateStepIds(steps) {
  const counts = new Map();
  for (const step of steps || []) {
    const id = normalizeString(step?.id, '');
    if (!id) {
      continue;
    }
    counts.set(id, (counts.get(id) || 0) + 1);
  }

  return [...counts.entries()].filter(([, count]) => count > 1).map(([id]) => id);
}

function hasNotesContradiction(notes) {
  const text = normalizeString(notes, '').toLowerCase();
  if (!text) {
    return false;
  }

  const contradictoryPairs = [
    ['possui dobras', 'nao possui dobras'],
    ['tem dobras', 'nao tem dobras'],
    ['possui furos', 'nao possui furos'],
    ['tem furos', 'nao tem furos'],
    ['com dobra', 'sem dobra'],
    ['com furo', 'sem furo'],
  ];

  return contradictoryPairs.some(([positive, negative]) => text.includes(positive) && text.includes(negative));
}

function normalizeMeasurementMode(rawMode, analysisType, fallbackMode = null) {
  const mode = normalizeString(rawMode, '').toLowerCase();
  if (!mode) {
    if (fallbackMode) {
      return normalizeMeasurementMode(fallbackMode, analysisType, null);
    }
    return analysisType === 'angle_profile' ? 'auto' : 'outer_span';
  }
  if (
    ['auto', 'outer_span', 'hole_diameter', 'center_distance', 'edge_to_hole_center', 'slot_width'].includes(mode)
  ) {
    return analysisType === 'angle_profile' ? 'auto' : mode;
  }
  return analysisType === 'angle_profile' ? 'auto' : 'outer_span';
}

function buildStepEvidenceText(step) {
  const checklist = Array.isArray(step?.capture_checklist) ? step.capture_checklist.join(' ') : '';
  return [step?.title, step?.instruction, step?.target_hint, step?.source_callout, checklist]
    .map((item) => normalizeString(item, ''))
    .join(' ')
    .toLowerCase();
}

function hasHoleDimensionMarker(text) {
  return /(?:ø|⌀|phi|diam(?:etro|eter)?|d\.?)\s*[0-9]/i.test(text || '');
}

function hasRadiusDimensionMarker(text) {
  return /(?:\br\s*[0-9]|raio\s*[0-9]|radius\s*[0-9])/i.test(text || '');
}

function hasBendDirectiveEvidence(text) {
  return /(dobra|linhas?\s+de\s+dobra|linha\s+de\s+dobra|para\s+cima|para\s+baixo|fold|bend|up\s*bend|down\s*bend|vinco)/i.test(
    text || '',
  );
}

function parseChamferLiteral(sourceText) {
  const text = normalizeString(sourceText, '');
  if (!text) {
    return null;
  }

  if (hasHoleDimensionMarker(text)) {
    return null;
  }

  const match = text.match(/(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)(?:\s*(?:deg|°|grau|graus))?/i);
  if (!match) {
    return null;
  }

  const sizeValue = normalizeNumber(match[1], 0);
  const angleValue = normalizeNumber(match[2], 0);
  if (sizeValue <= 0 || angleValue <= 0) {
    return null;
  }

  // Typical chamfer angle range. Avoid misclassifying generic AxB linear notes.
  if (angleValue < 30 || angleValue > 75) {
    return null;
  }

  return {
    size: sizeValue,
    angle: angleValue,
  };
}

function inferLinearEntityClassFromContext(text, orientationHint = 'unknown') {
  const normalizedText = normalizeString(text, '').toLowerCase();
  const orientation = normalizeString(orientationHint, 'unknown').toLowerCase();

  if (/(espessura|thickness|sheet\s*thickness|esp\.?\s*chapa|esp\.?\s*da\s*chapa)/i.test(normalizedText)) {
    return 'thickness';
  }
  if (/(altura|height|vertical|h\s*total|flange|aba)/i.test(normalizedText)) {
    return 'height';
  }
  if (/(base|comprimento|length|overall|largura\s+total|span)/i.test(normalizedText)) {
    return 'base';
  }
  if (orientation === 'vertical') {
    return 'height';
  }
  if (orientation === 'horizontal') {
    return 'base';
  }
  return 'base';
}

function parseCalloutValue(sourceCallout) {
  const callout = normalizeString(sourceCallout, '');
  if (!callout) {
    return null;
  }

  const hole = callout.match(/(?:ø|⌀|phi|diam(?:etro|eter)?|d\.?)\s*([0-9]+(?:[.,][0-9]+)?)/i);
  if (hole) {
    return {
      value: normalizeNumber(hole[1], 0),
      unit: 'mm',
      kind: 'hole',
    };
  }

  const chamfer = parseChamferLiteral(callout);
  if (chamfer) {
    return {
      value: chamfer.size,
      unit: 'mm',
      kind: 'chamfer',
    };
  }

  const angle = callout.match(/(\d+(?:[.,]\d+)?)\s*(?:deg|°|grau|graus)/i);
  if (angle) {
    return {
      value: normalizeNumber(angle[1], 0),
      unit: 'deg',
      kind: 'angle',
    };
  }

  const radius = callout.match(/(?:\br\s*|raio\s*)(\d+(?:[.,]\d+)?)/i);
  if (radius) {
    return {
      value: normalizeNumber(radius[1], 0),
      unit: 'mm',
      kind: 'radius',
    };
  }

  const literal = callout.match(/(\d+(?:[.,]\d+)?)/);
  if (!literal) {
    return null;
  }

  return {
    value: normalizeNumber(literal[1], 0),
    unit: 'mm',
    kind: 'linear',
  };
}

function inferStepClass(step, parsedCallout = null) {
  const callout = parsedCallout || parseCalloutValue(step?.source_callout);
  const text = buildStepEvidenceText(step);

  if (callout?.kind === 'hole' || /(furo|furos|hole|holes|diametro|diam\.|ø|⌀|phi)/i.test(text)) {
    return 'hole';
  }

  if (
    callout?.kind === 'chamfer' ||
    /chanfro|chamfer|(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(?:deg|°|grau|graus)/i.test(text)
  ) {
    return 'chamfer';
  }

  if (/(dobra|linhas?\s+de\s+dobra|para\s+cima|para\s+baixo|fold|bend|vinco)/i.test(text)) {
    return 'bend';
  }

  if (/(espessura|thickness|esp\.?\s*chapa|esp\.?\s*da\s*chapa)/i.test(text)) {
    return 'thickness';
  }

  if (/(rasgo|recorte|ranhura|slot|tipo\s*u|corte\s+u|recorte\s+u)/i.test(text)) {
    return 'u_cutout';
  }

  if (/(altura|height|vertical|h\s*total|h\.)/i.test(text)) {
    return 'height';
  }

  if (/(base|comprimento|length|overall|largura\s+total|span)/i.test(text)) {
    return 'base';
  }

  if (callout?.kind === 'angle') {
    return 'bend';
  }

  return 'other';
}

function resolveStepClass(step, parsedCallout = null) {
  const explicit = normalizeString(step?.step_class, '').toLowerCase();
  if (KNOWN_STEP_CLASSES.includes(explicit)) {
    return explicit;
  }
  return inferStepClass(step, parsedCallout);
}

function normalizeEntityViewHint(rawView) {
  const normalized = normalizeString(rawView, '').toLowerCase();
  if (!normalized) {
    return 'unknown';
  }
  if (['top', 'profile', 'front', 'detail', 'isometric'].includes(normalized)) {
    return normalized;
  }
  return 'unknown';
}

function normalizeEntitySymbolType(rawType, literal = '', evidenceText = '') {
  const normalizedRaw = normalizeString(rawType, '').toLowerCase();
  const text = `${literal} ${evidenceText} ${normalizedRaw}`.toLowerCase();
  const chamfer = parseChamferLiteral(literal);
  const hasBendEvidence = hasBendDirectiveEvidence(`${literal} ${evidenceText}`);
  const hasAngleLiteral = extractStandaloneAngleValue(literal) !== null;
  const hasGdtEvidence = /(gdt|datum|perpendicularidade|perpendicularity|parallelism|parallel|flatness|position|profile|⟂|∥|⌖|⌯|⌒|⌭|⌰)/i.test(
    `${literal} ${evidenceText}`,
  );

  if (KNOWN_ENTITY_SYMBOL_TYPES.includes(normalizedRaw)) {
    if (chamfer) {
      return 'chamfer';
    }
    if (normalizedRaw === 'bend_directive' && !hasBendEvidence && !hasAngleLiteral) {
      return /[0-9]+(?:[.,][0-9]+)?/.test(literal) ? 'linear' : 'unknown';
    }
    if ((normalizedRaw === 'gdt' || normalizedRaw === 'note') && !hasGdtEvidence && /[0-9]+(?:[.,][0-9]+)?/.test(literal)) {
      return 'linear';
    }
    return normalizedRaw;
  }

  if (chamfer) {
    return 'chamfer';
  }
  if (hasHoleDimensionMarker(text)) {
    return 'diameter';
  }
  if (hasRadiusDimensionMarker(text)) {
    return 'radius';
  }
  if (hasAngleLiteral) {
    return 'angle';
  }
  if (hasBendDirectiveEvidence(text)) {
    return 'bend_directive';
  }
  if (/(gdt|datum|perpendicularidade|parallelism|flatness|position|profile)/i.test(text)) {
    return 'gdt';
  }
  if (/(rosca|thread|m\d+\s*[x×]\s*\d)/i.test(text)) {
    return 'thread';
  }
  if (/(nota|note|obs\.?)/i.test(text)) {
    return 'note';
  }
  if (/[0-9]+(?:[.,][0-9]+)?/.test(text)) {
    return 'linear';
  }

  return 'unknown';
}

function normalizeEntityClass(rawClass, symbolType, literal = '', evidenceText = '', orientationHint = 'unknown') {
  const explicit = normalizeString(rawClass, '').toLowerCase();
  const text = `${literal} ${evidenceText}`.toLowerCase();
  const chamfer = parseChamferLiteral(literal);
  const hasBendEvidence = hasBendDirectiveEvidence(text);
  const hasAngleLiteral = extractStandaloneAngleValue(literal) !== null;
  const linearFallback = inferLinearEntityClassFromContext(text, orientationHint);

  if (KNOWN_STEP_CLASSES.includes(explicit)) {
    if (explicit === 'bend') {
      if (chamfer) {
        return 'chamfer';
      }
      if (!hasBendEvidence && !hasAngleLiteral && symbolType !== 'angle') {
        return linearFallback;
      }
    }
    if (explicit === 'hole' && !hasHoleDimensionMarker(text) && symbolType === 'radius') {
      return 'other';
    }
    if (explicit === 'other' && symbolType === 'linear' && /[0-9]+(?:[.,][0-9]+)?/.test(literal)) {
      return linearFallback;
    }
    return explicit;
  }

  if (chamfer || symbolType === 'chamfer' || /(chanfro|chamfer)/i.test(text)) {
    return 'chamfer';
  }

  if (symbolType === 'diameter' || /(furo|hole|ø|⌀|phi|diam(?:etro|eter)?|diam\.)/i.test(text)) {
    return 'hole';
  }

  if (symbolType === 'radius' && !hasHoleDimensionMarker(text)) {
    return 'other';
  }

  if ((symbolType === 'bend_directive' || symbolType === 'angle') && (hasBendEvidence || hasAngleLiteral)) {
    return 'bend';
  }

  if (/(espessura|thickness|esp\.?\s*chapa|esp\.?\s*da\s*chapa)/i.test(text)) {
    return 'thickness';
  }

  if (/(rasgo|recorte|ranhura|slot|tipo\s*u|corte\s+u|recorte\s+u)/i.test(text)) {
    return 'u_cutout';
  }

  if (/(altura|height|vertical|h\s*total|flange|aba)/i.test(text)) {
    return 'height';
  }

  if (/(base|comprimento|length|overall|largura\s+total|span)/i.test(text)) {
    return 'base';
  }

  if (symbolType === 'linear' && /[0-9]+(?:[.,][0-9]+)?/.test(literal)) {
    return linearFallback;
  }

  return 'other';
}

function extractQuantityFromLiteral(literal) {
  const text = normalizeString(literal, '');
  if (!text) {
    return 1;
  }

  const chamferPattern = /(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(?:deg|°|grau|graus)/i;
  if (chamferPattern.test(text)) {
    const qtyInParentheses = text.match(/\(([0-9]{1,3})\s*[x×]\)/i);
    if (qtyInParentheses) {
      return Math.max(1, Math.round(normalizeNumber(qtyInParentheses[1], 1)));
    }
    return 1;
  }

  const quantityAtStart = text.match(/^\s*([0-9]{1,3})\s*[x×]\s*(?:ø|⌀|phi|diam|furo|hole)/i);
  if (quantityAtStart) {
    return Math.max(1, Math.round(normalizeNumber(quantityAtStart[1], 1)));
  }

  const quantityInParentheses = text.match(/\(([0-9]{1,3})\s*[x×]\)/i);
  if (quantityInParentheses) {
    return Math.max(1, Math.round(normalizeNumber(quantityInParentheses[1], 1)));
  }

  return 1;
}

function entityLiteralKey(value) {
  return normalizeString(value, '')
    .toLowerCase()
    .replace(/ø|⌀/g, 'diam')
    .replace(/phi/g, 'diam')
    .replace(/diam(?:etro)?/g, 'diam')
    .replace(/[\s()]/g, '')
    .trim();
}

function extractEntityLedgerFromPayload(payload) {
  if (Array.isArray(payload)) {
    return payload;
  }
  if (!payload || typeof payload !== 'object') {
    return [];
  }
  if (Array.isArray(payload.entity_ledger)) {
    return payload.entity_ledger;
  }
  if (Array.isArray(payload.entities)) {
    return payload.entities;
  }
  if (Array.isArray(payload.callouts)) {
    return payload.callouts;
  }
  if (Array.isArray(payload.items)) {
    return payload.items;
  }
  return [];
}

function rebalanceFoundationalEntityClasses(entities = []) {
  const adjusted = (entities || []).map((entity) => ({ ...entity }));
  const hasClass = (className) =>
    adjusted.some((entity) => normalizeString(entity.feature_class, 'other') === className);

  const baseLinearEntries = () =>
    adjusted
      .map((entity, index) => ({ entity, index }))
      .filter(
        ({ entity }) =>
          normalizeString(entity.feature_class, 'other') === 'base' &&
          normalizeString(entity.symbol_type, 'unknown') === 'linear' &&
          normalizeNumber(entity.primary_value, 0) > 0,
      );

  if (!hasClass('thickness')) {
    const thicknessCandidates = baseLinearEntries()
      .filter(({ entity }) => isPlausibleThicknessValue(entity.primary_value))
      .map(({ entity, index }) => {
        const text = `${normalizeString(entity.literal, '')} ${normalizeString(entity.evidence, '')}`.toLowerCase();
        const viewHint = normalizeEntityViewHint(entity.view_hint);
        const hasThicknessCue = /(espessura|thickness|sheet\s*thickness)/i.test(text);
        const baseCue = /(base|comprimento|length|span|overall|horizontal)/i.test(text);
        let score = 0;
        if (hasThicknessCue) {
          score += 4;
        }
        if (['profile', 'front', 'detail'].includes(viewHint)) {
          score += 3;
        }
        if (normalizeString(entity.orientation_hint, 'unknown') === 'vertical') {
          score += 1;
        }
        if (baseCue) {
          score -= 3;
        }
        score += 1 / Math.max(1, normalizeNumber(entity.primary_value, 1));
        return { index, score };
      })
      .sort((left, right) => right.score - left.score);

    if (thicknessCandidates.length > 0 && thicknessCandidates[0].score >= 1) {
      adjusted[thicknessCandidates[0].index].feature_class = 'thickness';
    }
  }

  if (!hasClass('height')) {
    const heightCandidates = baseLinearEntries()
      .filter(({ entity }) => normalizeNumber(entity.primary_value, 0) > 20)
      .map(({ entity, index }) => {
        const text = `${normalizeString(entity.literal, '')} ${normalizeString(entity.evidence, '')}`.toLowerCase();
        const viewHint = normalizeEntityViewHint(entity.view_hint);
        const orientationHint = normalizeString(entity.orientation_hint, 'unknown');
        const hasHeightCue = /(altura|height|vertical|h\s*total)/i.test(text);
        const hasBaseCue = /(base|comprimento|length|span|overall|horizontal)/i.test(text);

        let score = 0;
        if (hasHeightCue) {
          score += 5;
        }
        if (orientationHint === 'vertical') {
          score += 4;
        }
        if (['front', 'profile'].includes(viewHint)) {
          score += 2;
        }
        if (hasBaseCue) {
          score -= 2;
        }
        score += normalizeNumber(entity.primary_value, 0) * 0.01;

        return { index, score, hasStrongCue: hasHeightCue || orientationHint === 'vertical' };
      })
      .sort((left, right) => right.score - left.score);

    if (heightCandidates.length > 0) {
      const hasStrongCue = heightCandidates.some((item) => item.hasStrongCue);
      if (hasStrongCue || heightCandidates.length >= 2) {
        adjusted[heightCandidates[0].index].feature_class = 'height';
      }
    }
  }

  return adjusted;
}

function normalizeEntityLedger(rawLedger) {
  const rawItems = extractEntityLedgerFromPayload(rawLedger);
  const deduplicated = new Map();

  for (let index = 0; index < rawItems.length; index += 1) {
    const item = rawItems[index] || {};

    const literal = normalizeString(
      item.literal || item.source_callout || item.callout || item.text || item.raw_text || item.label,
      '',
    );
    const evidence = normalizeString(item.evidence || item.context || item.reason || item.association, '');
    if (isTemplatePlaceholderText(literal)) {
      continue;
    }
    if (!literal && !evidence) {
      continue;
    }

    const orientationHintRaw = normalizeString(
      item.orientation_hint || item.axis_hint || item.orientation,
      'unknown',
    ).toLowerCase();
    const orientationHint = ['horizontal', 'vertical', 'auto', 'unknown'].includes(orientationHintRaw)
      ? orientationHintRaw
      : 'unknown';

    const symbolType = normalizeEntitySymbolType(item.symbol_type || item.type || item.kind, literal, evidence);
    let featureClass = normalizeEntityClass(
      item.feature_class || item.class_name || item.step_class,
      symbolType,
      literal,
      evidence,
      orientationHint,
    );
    const parsedCallout = parseCalloutValue(literal);
    const chamferLiteral = parseChamferLiteral(literal);

    const fallbackPrimary =
      symbolType === 'chamfer' && chamferLiteral
        ? normalizeNumber(chamferLiteral.size, parsedCallout?.value || 0)
        : parsedCallout?.value || 0;
    const fallbackSecondary =
      symbolType === 'chamfer' && chamferLiteral
        ? normalizeNumber(chamferLiteral.angle, 0)
        : 0;

    const primaryValue = normalizeNumber(
      item.primary_value ?? item.value ?? item.nominal ?? item.expected_value ?? fallbackPrimary,
      fallbackPrimary,
    );
    const secondaryValue = normalizeNumber(
      item.secondary_value ?? item.sub_value ?? fallbackSecondary,
      fallbackSecondary,
    );

    const confidence = clamp(
      normalizeNumber(item.confidence ?? item.score ?? item.reliability, primaryValue > 0 ? 0.72 : 0.55),
      0,
      1,
    );

    let quantity = Math.max(1, Math.round(normalizeNumber(item.quantity, extractQuantityFromLiteral(literal))));
    const unitFallback = parsedCallout?.unit || (symbolType === 'angle' ? 'deg' : 'mm');
    const rawUnit = normalizeString(item.unit, unitFallback).toLowerCase();
    const unit = ['mm', 'deg', 'unknown'].includes(rawUnit) ? rawUnit : unitFallback;

    const viewHint = normalizeEntityViewHint(item.view_hint || item.view || item.required_view);

    if (symbolType === 'chamfer') {
      const qtyInParentheses = literal.match(/\(([0-9]{1,3})\s*[x×]\)/i);
      quantity = qtyInParentheses
        ? Math.max(1, Math.round(normalizeNumber(qtyInParentheses[1], 1)))
        : 1;
    }

    // Rebalance ambiguous linear classes using value+view heuristics.
    if (symbolType === 'linear' && featureClass === 'base') {
      const text = `${literal} ${evidence}`.toLowerCase();
      if (
        isPlausibleThicknessValue(primaryValue) &&
        ['profile', 'front', 'detail'].includes(viewHint) &&
        !/(base|comprimento|length|span|overall|horizontal)/i.test(text)
      ) {
        featureClass = 'thickness';
      } else if (
        primaryValue > 20 &&
        (orientationHint === 'vertical' || /(altura|height|vertical|h\s*total)/i.test(text))
      ) {
        featureClass = 'height';
      }
    }

    const dedupeKey = `${featureClass}|${symbolType}|${entityLiteralKey(literal)}|${primaryValue.toFixed(4)}|${viewHint}`;
    const normalizedEntity = {
      id: normalizeString(item.id, `ENT_${index + 1}`),
      literal,
      symbol_type: symbolType,
      feature_class: featureClass,
      primary_value: primaryValue,
      secondary_value: secondaryValue,
      quantity,
      unit,
      view_hint: viewHint,
      orientation_hint: orientationHint,
      confidence,
      evidence,
    };

    const previous = deduplicated.get(dedupeKey);
    if (!previous || previous.confidence < normalizedEntity.confidence) {
      deduplicated.set(dedupeKey, normalizedEntity);
    }
  }

  const balancedEntities = rebalanceFoundationalEntityClasses([...deduplicated.values()]);

  return balancedEntities
    .sort((left, right) => right.confidence - left.confidence || left.literal.localeCompare(right.literal))
    .slice(0, LEDGER_MAX_ENTITIES)
    .map((entity, index) => ({
      ...entity,
      id: `ENT_${index + 1}`,
    }));
}

function countMeasurableLedgerEntities(entityLedger = []) {
  return (entityLedger || []).filter((entity) => isMeasurableLedgerEntity(entity)).length;
}

function choosePreferredEntityLedger(extractedLedger = [], seedLedger = []) {
  const extracted = normalizeEntityLedger(extractedLedger || []);
  const seed = normalizeEntityLedger(seedLedger || []);

  if (!extracted.length) {
    return seed;
  }
  if (!seed.length) {
    return extracted;
  }

  const extractedMeasurable = countMeasurableLedgerEntities(extracted);
  const seedMeasurable = countMeasurableLedgerEntities(seed);

  if (seedMeasurable >= extractedMeasurable + 2) {
    return seed;
  }
  if (extractedMeasurable >= seedMeasurable + 2) {
    return extracted;
  }

  return normalizeEntityLedger([...seed, ...extracted]);
}

function isMeasurableLedgerEntity(entity) {
  if (!entity) {
    return false;
  }
  if (['gdt', 'note', 'thread', 'unknown'].includes(normalizeString(entity.symbol_type, 'unknown'))) {
    return false;
  }

  const featureClass = normalizeString(entity.feature_class, 'other');
  if (!FOCUS_CLASSES.includes(featureClass)) {
    return false;
  }

  const value = normalizeNumber(entity.primary_value, 0);
  if (value > 0) {
    return true;
  }

  if (featureClass === 'bend') {
    return extractStandaloneAngleValue(entity.literal) !== null;
  }

  return false;
}

function collectEvidenceRequiredClasses(entityLedger = []) {
  const required = new Set();
  for (const entity of entityLedger) {
    if (!isMeasurableLedgerEntity(entity)) {
      continue;
    }
    if (normalizeNumber(entity.confidence, 0) < MIN_LEDGER_ENTITY_CONFIDENCE) {
      continue;
    }
    if (FOCUS_CLASSES.includes(entity.feature_class)) {
      required.add(entity.feature_class);
    }
  }
  return [...required];
}

function findMatchingEntityForStep(step, entityLedger = []) {
  if (!entityLedger.length) {
    return null;
  }

  const sourceCallout = normalizeString(step?.source_callout, '');
  const stepClass = resolveStepClass(step, parseCalloutValue(sourceCallout));
  const normalizedLiteral = entityLiteralKey(sourceCallout);

  if (normalizedLiteral) {
    const directLiteralMatch = entityLedger.find((entity) => {
      if (entityLiteralKey(entity.literal) !== normalizedLiteral) {
        return false;
      }
      return stepClass === 'other' || entity.feature_class === stepClass || entity.feature_class === 'other';
    });
    if (directLiteralMatch) {
      return directLiteralMatch;
    }
  }

  const parsedCallout = parseCalloutValue(sourceCallout);
  const expectedValue = normalizeNumber(step?.expected_value, 0);
  const referenceValue = parsedCallout?.value > 0 ? parsedCallout.value : expectedValue;
  if (referenceValue <= 0) {
    return null;
  }

  return entityLedger.find((entity) => {
    if (stepClass !== 'other' && entity.feature_class !== stepClass) {
      return false;
    }
    const entityValue = normalizeNumber(entity.primary_value, 0);
    if (entityValue <= 0) {
      return false;
    }
    const tolerance = Math.max(0.01, referenceValue * 0.01);
    return Math.abs(entityValue - referenceValue) <= tolerance;
  });
}

function inferLinearClassFromEntity(entity) {
  return inferLinearEntityClassFromContext(
    `${normalizeString(entity?.literal, '')} ${normalizeString(entity?.evidence, '')}`,
    normalizeString(entity?.orientation_hint, 'unknown'),
  );
}

function buildStepFromLedgerEntity(entity, index) {
  let stepClass = normalizeEntityClass(
    entity.feature_class,
    entity.symbol_type,
    entity.literal,
    entity.evidence,
    normalizeString(entity.orientation_hint, 'unknown'),
  );

  if (!FOCUS_CLASSES.includes(stepClass) && normalizeString(entity.symbol_type, 'unknown') === 'linear') {
    const fallbackClass = inferLinearClassFromEntity(entity);
    if (FOCUS_CLASSES.includes(fallbackClass)) {
      stepClass = fallbackClass;
    }
  }

  if (!FOCUS_CLASSES.includes(stepClass)) {
    return null;
  }

  let expectedValue = normalizeNumber(entity.primary_value, 0);
  let analysisType = 'aruco_2d';
  let unit = 'mm';

  if (stepClass === 'bend') {
    const symbolType = normalizeString(entity.symbol_type, 'unknown');
    const bendEvidence = hasBendDirectiveEvidence(`${entity.literal} ${entity.evidence}`);
    const inferredAngle = extractStandaloneAngleValue(entity.literal);
    const hasAngularEvidence = inferredAngle !== null || symbolType === 'angle' || normalizeString(entity.unit, '').toLowerCase() === 'deg';
    const hasBendSemanticEvidence = bendEvidence || symbolType === 'bend_directive';

    if (!hasAngularEvidence || !hasBendSemanticEvidence) {
      const fallbackClass = inferLinearClassFromEntity(entity);
      if (FOCUS_CLASSES.includes(fallbackClass) && fallbackClass !== 'bend') {
        stepClass = fallbackClass;
      } else {
        return null;
      }
    }

    const angleValue = inferredAngle ?? normalizeNumber(entity.primary_value, 0);
    if (stepClass === 'bend' && angleValue > 0 && angleValue < 180) {
      expectedValue = angleValue;
      analysisType = 'angle_profile';
      unit = 'deg';
    } else if (stepClass === 'bend') {
      return null;
    }
  }

  if (stepClass === 'chamfer') {
    const parsedChamfer = parseCalloutValue(entity.literal);
    if (parsedChamfer?.kind === 'chamfer' && parsedChamfer.value > 0) {
      expectedValue = parsedChamfer.value;
    }
  }

  if (expectedValue <= 0) {
    return null;
  }

  const requiredView =
    stepClass === 'bend' || stepClass === 'thickness'
      ? 'profile'
      : stepClass === 'u_cutout'
      ? 'detail'
      : normalizeView(entity.view_hint, 'top');

  const sourceCallout = normalizeString(entity.literal, '');
  const targetHint = normalizeString(entity.evidence, sourceCallout || `feature_${stepClass}`);
  const measurementMode = stepClass === 'hole' ? 'hole_diameter' : defaultMeasurementMode(analysisType, stepClass);
  const tolerance = defaultToleranceForStep(unit, expectedValue, stepClass);

  let title = `Verificar ${stepClass}`;
  if (stepClass === 'base') {
    title = sourceCallout ? `Cota de base (${sourceCallout})` : 'Cota de base';
  } else if (stepClass === 'height') {
    title = sourceCallout ? `Cota de altura (${sourceCallout})` : 'Cota de altura';
  } else if (stepClass === 'thickness') {
    title = sourceCallout ? `Espessura (${sourceCallout})` : 'Espessura da chapa';
  } else if (stepClass === 'hole') {
    title = sourceCallout ? `Diametro de furo (${sourceCallout})` : 'Diametro de furo';
  } else if (stepClass === 'chamfer') {
    title = sourceCallout ? `Chanfro (${sourceCallout})` : 'Chanfro';
  } else if (stepClass === 'bend') {
    title = sourceCallout ? `Angulo de dobra (${sourceCallout})` : 'Angulo de dobra';
  } else if (stepClass === 'u_cutout') {
    title = sourceCallout ? `Recorte tipo U (${sourceCallout})` : 'Recorte tipo U';
  }

  const instruction =
    stepClass === 'bend'
      ? `Capturar perfil ortogonal para medir o angulo de dobra ${sourceCallout || ''}.`.trim()
      : stepClass === 'hole'
      ? `Capturar vista ortogonal para medir diametro do furo ${sourceCallout || ''}.`.trim()
      : `Medir cota ${sourceCallout || ''} em vista ${requiredView}.`.trim();

  const captureHints = buildStepCaptureHints(
    {
      required_view: requiredView,
      instruction,
      target_hint: targetHint,
      source_callout: sourceCallout,
    },
    stepClass,
  );

  return {
    id: `STEP_${index + 1}`,
    title,
    instruction,
    required_view: requiredView,
    analysis_type: analysisType,
    measurement_mode: measurementMode,
    axis_preference: normalizeAxisPreference(entity.orientation_hint, 'auto'),
    target_hint: targetHint,
    source_callout: sourceCallout,
    expected_value: expectedValue,
    tolerance,
    unit,
    step_class: stepClass,
    requires_all_markers: analysisType === 'aruco_2d',
    capture_checklist: ['4 ArUco visiveis', 'alvo completo e nitido'],
    hidden_feature_candidate: captureHints.hidden_feature_candidate,
    occlusion_risk: captureHints.occlusion_risk,
    recommended_capture_pose: captureHints.recommended_capture_pose,
    verification_focus: captureHints.verification_focus,
  };
}

function ensureSequentialStepIds(steps = []) {
  return steps.map((step, index) => ({
    ...step,
    id: `STEP_${index + 1}`,
  }));
}

function augmentStepsWithEntityLedger(steps = [], entityLedger = []) {
  if (!entityLedger.length) {
    return ensureSequentialStepIds(steps);
  }

  const merged = [...steps];
  const signatures = new Set(merged.map((step) => stepSignature(step)));

  for (const entity of entityLedger) {
    if (!isMeasurableLedgerEntity(entity)) {
      continue;
    }
    if (normalizeNumber(entity.confidence, 0) < MIN_LEDGER_ENTITY_CONFIDENCE) {
      continue;
    }

    const candidate = buildStepFromLedgerEntity(entity, merged.length);
    if (!candidate) {
      continue;
    }

    const signature = stepSignature(candidate);
    if (signatures.has(signature)) {
      continue;
    }

    signatures.add(signature);
    merged.push(candidate);
  }

  return ensureSequentialStepIds(merged);
}

function isPlaceholderLikeStep(step = {}) {
  const title = normalizeString(step?.title, '');
  const instruction = normalizeString(step?.instruction, '');
  const targetHint = normalizeString(step?.target_hint, '');
  const sourceCallout = normalizeString(step?.source_callout, '');
  const stepClass = normalizeString(step?.step_class, 'other').toLowerCase();

  const placeholderFieldCount = [title, instruction, targetHint, sourceCallout].filter((value) =>
    isTemplatePlaceholderText(value),
  ).length;

  const parsedCallout = parseCalloutValue(sourceCallout);
  const hasLiteralMeasurement = parsedCallout && normalizeNumber(parsedCallout.value, 0) > 0;

  const expectedValue = normalizeNumber(step?.expected_value, 0);
  const tolerance = normalizeNumber(step?.tolerance, 0);
  const unit = normalizeString(step?.unit, '').toLowerCase();
  const analysisType = normalizeString(step?.analysis_type, '').toLowerCase();
  const measurementMode = normalizeString(step?.measurement_mode, '').toLowerCase();

  const suspiciousDefaultBundle =
    expectedValue === 10 &&
    tolerance === 0.5 &&
    unit === 'mm' &&
    analysisType === 'aruco_2d' &&
    measurementMode === 'outer_span';

  if (placeholderFieldCount >= 2) {
    return true;
  }

  if (!hasLiteralMeasurement && isTemplatePlaceholderText(sourceCallout)) {
    return true;
  }

  if (suspiciousDefaultBundle && stepClass === 'other' && placeholderFieldCount >= 1) {
    return true;
  }

  return false;
}

function scoreStepVariant(step) {
  const callout = parseCalloutValue(step?.source_callout);
  const stepClass = resolveStepClass(step, callout);
  const analysisType = normalizeString(step?.analysis_type, '').toLowerCase();
  const unit = normalizeString(step?.unit, '').toLowerCase();
  const measurementMode = normalizeString(step?.measurement_mode, '').toLowerCase();

  let score = 0;

  if (stepClass === 'bend') {
    if (analysisType === 'angle_profile') {
      score += 4;
    }
    if (unit === 'deg') {
      score += 2;
    }
    if (callout?.kind === 'chamfer') {
      score -= 4;
    }
  } else {
    if (analysisType === 'aruco_2d') {
      score += 2;
    }
    if (unit === 'mm') {
      score += 1;
    }
  }

  if (stepClass === 'hole' && measurementMode === 'hole_diameter') {
    score += 2;
  }

  if (stepClass === 'chamfer' && callout?.kind === 'chamfer') {
    score += 2;
  }

  if (normalizeString(step?.source_callout, '')) {
    score += 1;
  }

  return score;
}

function resolveConflictingStepVariants(steps = []) {
  const bestByKey = new Map();

  for (let index = 0; index < steps.length; index += 1) {
    const step = steps[index];
    const source = normalizeString(step?.source_callout, '').replace(/\s+/g, '').toLowerCase();
    if (!source) {
      bestByKey.set(`__no_source_${index}`, { step, index, score: scoreStepVariant(step) });
      continue;
    }

    const stepClass = resolveStepClass(step, parseCalloutValue(step.source_callout));
    const key = `${stepClass}|${source}`;
    const candidate = { step, index, score: scoreStepVariant(step) };
    const current = bestByKey.get(key);

    if (!current || candidate.score > current.score) {
      bestByKey.set(key, candidate);
    }
  }

  return [...bestByKey.values()]
    .sort((left, right) => left.index - right.index)
    .map((entry) => entry.step);
}

function deriveFoundationalEntityFromStep(step, index = 0) {
  const sourceCallout = normalizeString(step?.source_callout, '');
  if (!sourceCallout || isTemplatePlaceholderText(sourceCallout)) {
    return null;
  }

  const callout = parseCalloutValue(sourceCallout);
  if (!callout || callout.value <= 0 || callout.kind !== 'linear') {
    return null;
  }

  let featureClass = resolveStepClass(step, callout);
  const evidenceText = [step?.title, step?.instruction, step?.target_hint].map((item) => normalizeString(item, '')).join(' ');
  const viewHint = normalizeEntityViewHint(step?.required_view);
  const axisPreference = normalizeAxisPreference(step?.axis_preference, 'auto');

  if (featureClass === 'other') {
    featureClass = inferLinearEntityClassFromContext(evidenceText, axisPreference);
  }

  if (featureClass === 'base') {
    if (/(altura|height|vertical)/i.test(evidenceText) || axisPreference === 'vertical') {
      featureClass = 'height';
    } else if (
      ['front', 'profile'].includes(normalizeView(step?.required_view, 'top')) &&
      callout.value > 20 &&
      !isPlausibleThicknessValue(callout.value) &&
      !/(base|comprimento|length|horizontal|span)/i.test(evidenceText)
    ) {
      featureClass = 'height';
    }
  }

  if (featureClass === 'base' && isPlausibleThicknessValue(callout.value) && ['front', 'profile'].includes(viewHint)) {
    featureClass = 'thickness';
  }

  if (!['base', 'height', 'thickness'].includes(featureClass)) {
    return null;
  }

  if (featureClass === 'thickness' && !isPlausibleThicknessValue(callout.value)) {
    return null;
  }

  return {
    id: `ENT_STEP_${index + 1}`,
    literal: sourceCallout,
    symbol_type: 'linear',
    feature_class: featureClass,
    primary_value: callout.value,
    secondary_value: 0,
    quantity: 1,
    unit: 'mm',
    view_hint: viewHint === 'unknown' ? normalizeEntityViewHint(normalizeView(step?.required_view, 'top')) : viewHint,
    orientation_hint:
      axisPreference === 'auto' ? 'unknown' : axisPreference,
    confidence: 0.58,
    evidence: normalizeString(step?.target_hint, normalizeString(step?.title, 'step_backfill')), 
  };
}

function mergeLedgerWithFoundationalStepEvidence(entityLedger = [], steps = []) {
  const normalizedLedger = normalizeEntityLedger(entityLedger || []);
  const existingLiteralKeys = new Set(
    normalizedLedger.map((entity) => `${entityLiteralKey(entity.literal)}|${normalizeString(entity.feature_class, 'other')}`),
  );

  const additions = [];
  for (let index = 0; index < steps.length; index += 1) {
    const step = steps[index];
    if (!step || isPlaceholderLikeStep(step)) {
      continue;
    }

    const candidate = deriveFoundationalEntityFromStep(step, index);
    if (!candidate) {
      continue;
    }

    const key = `${entityLiteralKey(candidate.literal)}|${candidate.feature_class}`;
    if (existingLiteralKeys.has(key)) {
      continue;
    }

    existingLiteralKeys.add(key);
    additions.push(candidate);
  }

  if (!additions.length) {
    return normalizedLedger;
  }

  return normalizeEntityLedger([...normalizedLedger, ...additions]);
}

function filterUnsupportedSteps(steps = [], entityLedger = []) {
  const hasLedger = Array.isArray(entityLedger) && entityLedger.length > 0;
  const filtered = [];
  const signatures = new Set();

  for (const step of steps || []) {
    if (!step) {
      continue;
    }

    if (isPlaceholderLikeStep(step)) {
      continue;
    }

    if (hasLedger && LEDGER_STRICT_MAPPING) {
      const matchedEntity = findMatchingEntityForStep(step, entityLedger);
      if (!matchedEntity) {
        const parsedCallout = parseCalloutValue(step?.source_callout);
        const stepClass = resolveStepClass(step, parsedCallout);
        const missingFoundationalClass =
          ['base', 'height', 'thickness'].includes(stepClass) &&
          !entityLedger.some(
            (entity) =>
              normalizeEntityClass(
                entity.feature_class,
                entity.symbol_type,
                entity.literal,
                entity.evidence,
                entity.orientation_hint,
              ) === stepClass,
          );
        const hasStrongLiteral = parsedCallout?.value > 0;

        if (!(missingFoundationalClass && hasStrongLiteral)) {
          continue;
        }
      }
    }

    const signature = stepSignature(step);
    if (signatures.has(signature)) {
      continue;
    }
    signatures.add(signature);
    filtered.push(step);
  }

  const resolved = resolveConflictingStepVariants(filtered);
  return ensureSequentialStepIds(resolved);
}

function buildFallbackPlanFromLedger(entityLedger = [], basePlan = null) {
  const normalizedLedger = normalizeEntityLedger(entityLedger || []);
  const measurableEntities = normalizedLedger.filter((entity) => isMeasurableLedgerEntity(entity));
  const signatures = new Set();
  const synthesized = [];

  const tryAppendEntityStep = (entity) => {
    const candidate = buildStepFromLedgerEntity(entity, synthesized.length);
    if (!candidate) {
      return false;
    }
    const signature = stepSignature(candidate);
    if (signatures.has(signature)) {
      return false;
    }
    signatures.add(signature);
    synthesized.push(candidate);
    return true;
  };

  for (const entity of measurableEntities) {
    if (normalizeNumber(entity.confidence, 0) < MIN_LEDGER_ENTITY_CONFIDENCE) {
      continue;
    }
    tryAppendEntityStep(entity);
  }

  // Em fallback total, prefere manter cobertura minima mesmo com baixa confianca.
  if (synthesized.length === 0) {
    for (const entity of measurableEntities) {
      tryAppendEntityStep(entity);
    }
  }

  const steps = ensureSequentialStepIds(synthesized);
  const hasHoleStep = steps.some((step) => resolveStepClass(step, parseCalloutValue(step.source_callout)) === 'hole');
  const hasBendStep = steps.some((step) => resolveStepClass(step, parseCalloutValue(step.source_callout)) === 'bend');

  return {
    geometry_check: {
      is_flat_plate: normalizeBool(basePlan?.geometry_check?.is_flat_plate, true),
      has_physical_bends_or_folds:
        hasBendStep ||
        normalizeBool(basePlan?.geometry_check?.has_physical_bends_or_folds, false),
      has_circular_holes:
        hasHoleStep ||
        normalizeBool(basePlan?.geometry_check?.has_circular_holes, false),
    },
    part_name: normalizePartName(basePlan?.part_name, 'Peca inferida por evidencias'),
    unit: normalizeString(basePlan?.unit, 'mm'),
    notes: normalizePlanNotes(
      basePlan?.notes,
      'Plano sintetizado a partir do entity_ledger devido resposta do modelo nao estruturada em JSON.',
    ),
    entity_ledger: normalizedLedger,
    steps,
  };
}

function summarizeEntityLedger(entityLedger = []) {
  const byClass = {
    base: 0,
    height: 0,
    thickness: 0,
    hole: 0,
    chamfer: 0,
    bend: 0,
    u_cutout: 0,
    other: 0,
  };

  let measurable = 0;
  for (const entity of entityLedger) {
    const featureClass = normalizeEntityClass(entity.feature_class, entity.symbol_type, entity.literal, entity.evidence);
    byClass[featureClass] = (byClass[featureClass] || 0) + 1;
    if (isMeasurableLedgerEntity(entity)) {
      measurable += 1;
    }
  }

  return {
    total_entities: entityLedger.length,
    measurable_entities: measurable,
    by_class: byClass,
  };
}

function hasMeasurableBendEvidence(plan) {
  const steps = Array.isArray(plan?.steps) ? plan.steps : [];
  for (const step of steps) {
    const callout = parseCalloutValue(step?.source_callout);
    const stepClass = resolveStepClass(step, callout);

    if (stepClass === 'bend' || normalizeString(step?.analysis_type, '') === 'angle_profile') {
      return true;
    }

    if (stepClass === 'chamfer') {
      continue;
    }

    const standalone =
      extractStandaloneAngleValue(step?.source_callout) ??
      extractStandaloneAngleValue(step?.target_hint) ??
      extractStandaloneAngleValue(step?.title) ??
      extractStandaloneAngleValue(step?.instruction);
    if (standalone !== null) {
      return true;
    }
  }
  return false;
}

function defaultMeasurementMode(analysisType, stepClass) {
  if (analysisType === 'angle_profile') {
    return 'auto';
  }
  if (stepClass === 'hole') {
    return 'hole_diameter';
  }
  if (stepClass === 'u_cutout') {
    return 'slot_width';
  }
  return 'outer_span';
}

function defaultToleranceForStep(unit, expectedValue, stepClass) {
  if (unit === 'deg') {
    return 1.0;
  }

  if (stepClass === 'hole') {
    return expectedValue <= 20 ? 0.15 : 0.2;
  }

  if (stepClass === 'thickness') {
    return 0.15;
  }

  if (stepClass === 'chamfer') {
    return 0.3;
  }

  return expectedValue > 0 && expectedValue <= 20 ? 0.2 : 0.5;
}

function analyzeClassCoverage(plan) {
  const counts = {
    base: 0,
    height: 0,
    thickness: 0,
    hole: 0,
    chamfer: 0,
    bend: 0,
    u_cutout: 0,
    other: 0,
  };

  for (const step of plan.steps || []) {
    const stepClass = resolveStepClass(step, parseCalloutValue(step?.source_callout));
    counts[stepClass] = (counts[stepClass] || 0) + 1;
  }

  const entityLedger = Array.isArray(plan?.entity_ledger) ? plan.entity_ledger : [];
  const evidenceSummary = summarizeEntityLedger(entityLedger);
  const evidenceRequiredClasses = collectEvidenceRequiredClasses(entityLedger);

  const required = new Set();
  if (evidenceRequiredClasses.length > 0) {
    evidenceRequiredClasses.forEach((item) => required.add(item));
  } else {
    CORE_REQUIRED_CLASSES.forEach((item) => required.add(item));
  }

  if (required.size === 0) {
    CORE_REQUIRED_CLASSES.forEach((item) => required.add(item));
  }

  if (plan.geometry_check?.has_circular_holes || counts.hole > 0) {
    required.add('hole');
  }
  if ((plan.geometry_check?.has_physical_bends_or_folds && hasMeasurableBendEvidence(plan)) || counts.bend > 0) {
    required.add('bend');
  }

  const requiredClasses = [...required];

  const missingRequired = requiredClasses.filter((item) => !counts[item]);
  const missingFocus = FOCUS_CLASSES.filter((item) => !counts[item]);

  return {
    by_class: counts,
    evidence_by_class: evidenceSummary.by_class,
    evidence_measurable_entities: evidenceSummary.measurable_entities,
    required_classes: requiredClasses,
    evidence_required_classes: evidenceRequiredClasses,
    missing_required_classes: missingRequired,
    focus_classes: FOCUS_CLASSES,
    missing_focus_classes: missingFocus,
    covered_focus_classes: FOCUS_CLASSES.filter((item) => counts[item] > 0),
  };
}

function humanizeClassName(className) {
  const labels = {
    base: 'BASE',
    height: 'ALTURA',
    thickness: 'ESPESSURA',
    hole: 'FURO',
    chamfer: 'CHANFRO',
    bend: 'DOBRA',
    u_cutout: 'RECORTE_U',
    other: 'OUTROS',
  };
  return labels[className] || className;
}

function buildStepCaptureHints(step, stepClass) {
  const requiredView = normalizeView(
    step.required_view,
    stepClass === 'thickness' || stepClass === 'bend' ? 'profile' : 'top',
  );

  const hiddenFeatureCandidate =
    ['hole', 'bend', 'u_cutout'].includes(stepClass) || ['profile', 'detail'].includes(requiredView);

  const occlusionRisk =
    stepClass === 'bend' || (stepClass === 'hole' && ['profile', 'detail'].includes(requiredView))
      ? 'high'
      : hiddenFeatureCandidate
      ? 'medium'
      : 'low';

  let recommendedCapturePose = 'camera_perpendicular_to_surface';
  if (requiredView === 'profile') {
    recommendedCapturePose = 'camera_perpendicular_to_profile';
  } else if (requiredView === 'detail') {
    recommendedCapturePose = 'closeup_with_aruco_reference';
  } else if (stepClass === 'hole') {
    recommendedCapturePose = 'top_view_centered_on_hole_axis';
  }

  const verificationFocus = [];
  if (stepClass === 'bend') {
    verificationFocus.push('capturar linha de dobra completa sem perspectiva inclinada');
    verificationFocus.push('se necessario, capturar os dois lados do perfil');
  } else if (stepClass === 'hole') {
    verificationFocus.push('centralizar o furo no quadro com bordas visiveis');
    verificationFocus.push('se houver sombra/oclusao, adicionar foto do lado oposto');
  } else if (stepClass === 'chamfer') {
    verificationFocus.push('evidenciar aresta chanfrada com iluminacao lateral uniforme');
  } else if (stepClass === 'thickness') {
    verificationFocus.push('mostrar secao de perfil com borda nitida da chapa');
  } else {
    verificationFocus.push('evitar sombras fortes e oclusao parcial do alvo');
  }

  return {
    hidden_feature_candidate: hiddenFeatureCandidate,
    occlusion_risk: occlusionRisk,
    recommended_capture_pose: recommendedCapturePose,
    verification_focus: verificationFocus,
  };
}

function findClosestStandardThickness(value) {
  const normalizedValue = normalizeNumber(value, 0);
  if (normalizedValue <= 0) {
    return null;
  }

  let closest = STANDARD_THICKNESS_MM[0];
  let bestDelta = Math.abs(closest - normalizedValue);
  for (const candidate of STANDARD_THICKNESS_MM) {
    const delta = Math.abs(candidate - normalizedValue);
    if (delta < bestDelta) {
      closest = candidate;
      bestDelta = delta;
    }
  }

  return {
    measured_value: normalizedValue,
    closest_standard_mm: closest,
    delta_mm: Number(bestDelta.toFixed(3)),
  };
}

function isPlausibleThicknessValue(value) {
  const normalized = normalizeNumber(value, 0);
  // Para o escopo atual de perfis dobrados do manual, espessuras acima disso tendem a ser outra cota.
  return normalized > 0 && normalized <= 20;
}

function extractStandaloneAngleValue(text) {
  const source = normalizeString(text, '');
  if (!source) {
    return null;
  }

  // Evita capturar o 45 de notacoes Nx45 (chanfro), focando em angulo standalone.
  const match = source.match(/(?:^|[^x×0-9])(\d+(?:[.,]\d+)?)\s*(?:deg|°|grau|graus)/i);
  if (!match) {
    return null;
  }

  const value = normalizeNumber(match[1], 0);
  if (value <= 0 || value >= 180) {
    return null;
  }
  return value;
}

function hasBendKeyword(text) {
  return /(dobra|linhas?\s+de\s+dobra|para\s+cima|para\s+baixo|fold|bend|vinco)/i.test(text || '');
}

function stepSuggestsPhysicalBend(step) {
  const text = buildStepEvidenceText(step);
  const callout = parseCalloutValue(step?.source_callout);
  const stepClass = resolveStepClass(step, callout);

  if (callout?.kind === 'chamfer' || stepClass === 'chamfer') {
    return false;
  }

  if (stepClass === 'bend') {
    return true;
  }

  if (/linhas?\s+de\s+dobra|para\s+cima|para\s+baixo/i.test(text)) {
    return true;
  }

  if (callout?.kind === 'angle') {
    return true;
  }

  return extractStandaloneAngleValue(text) !== null;
}

function normalizeChamferWording(step) {
  if (resolveStepClass(step, parseCalloutValue(step?.source_callout)) !== 'chamfer') {
    return step;
  }

  const calloutText = normalizeString(step.source_callout || step.target_hint, '').trim();
  const titleNeedsFix = /(dobra|bend|fold)/i.test(normalizeString(step.title, ''));
  const instructionNeedsFix = /(dobra|bend|fold)/i.test(normalizeString(step.instruction, ''));

  const fixedChecklist = Array.isArray(step.capture_checklist)
    ? step.capture_checklist.map((item) => {
        const upper = normalizeString(item, '').toUpperCase();
        if (upper.includes('DOBRA') || upper.includes('BEND')) {
          return 'CHANFRO';
        }
        return item;
      })
    : [];

  return {
    ...step,
    title: titleNeedsFix
      ? calloutText
        ? `Medicao de chanfro (${calloutText})`
        : 'Medicao de chanfro'
      : step.title,
    instruction: instructionNeedsFix
      ? calloutText
        ? `Medir o chanfro ${calloutText} em vista ortogonal, com foco na aresta.`
        : 'Medir o chanfro em vista ortogonal, com foco na aresta.'
      : step.instruction,
    capture_checklist: fixedChecklist,
  };
}

function refineNormalizedStep(step) {
  let refined = { ...step };
  const refinedCallout = parseCalloutValue(refined?.source_callout);
  const refinedText = buildStepEvidenceText(refined);
  const refinedClass = resolveStepClass(refined, refinedCallout);
  const refinedView = normalizeView(refined.required_view, 'top');
  const refinedValue = normalizeNumber(refined.expected_value, 0);
  const baseKeywordPattern = /(base|comprimento|length|span|overall|horizontal)/i;

  if (refinedClass === 'base') {
    if (
      (/(altura|height|vertical)/i.test(refinedText) || normalizeAxisPreference(refined.axis_preference, 'auto') === 'vertical') &&
      refinedValue > 0
    ) {
      refined.step_class = 'height';
    } else if (
      isPlausibleThicknessValue(refinedValue) &&
      ['profile', 'front', 'detail'].includes(refinedView) &&
      !baseKeywordPattern.test(refinedText)
    ) {
      refined.step_class = 'thickness';
      refined.required_view = 'profile';
    } else if (
      refinedValue > 20 &&
      ['profile', 'front'].includes(refinedView) &&
      !baseKeywordPattern.test(refinedText)
    ) {
      refined.step_class = 'height';
    }
  }

  if (resolveStepClass(refined, parseCalloutValue(refined?.source_callout)) === 'other') {
    const text = buildStepEvidenceText(refined);
    if (/(espessura|thickness)/i.test(text) && isPlausibleThicknessValue(refined.expected_value)) {
      refined.step_class = 'thickness';
      refined.required_view = 'profile';
    } else if (/(altura|height|vertical|aba|flange)/i.test(text)) {
      refined.step_class = 'height';
    } else if (/(base|comprimento|length|span)/i.test(text)) {
      refined.step_class = 'base';
    }
  }

  if (
    resolveStepClass(refined, parseCalloutValue(refined?.source_callout)) !== 'thickness' &&
    /(espessura|thickness)/i.test(buildStepEvidenceText(refined))
  ) {
    const callout = normalizeString(refined.source_callout || refined.target_hint, '').trim();
    refined.title = callout ? `Cota de perfil (${callout})` : 'Cota de perfil';
    refined.instruction = callout
      ? `Medir cota linear de perfil ${callout} com camera ortogonal.`
      : 'Medir cota linear de perfil com camera ortogonal.';
    refined.capture_checklist = Array.isArray(refined.capture_checklist)
      ? refined.capture_checklist.map((item) => {
          const upper = normalizeString(item, '').toUpperCase();
          return upper.includes('ESPESSURA') ? 'COTA_PERFIL' : item;
        })
      : [];
  }

  if (resolveStepClass(refined, parseCalloutValue(refined?.source_callout)) !== 'bend' && refined.analysis_type === 'angle_profile') {
    refined.analysis_type = 'aruco_2d';
    refined.unit = 'mm';
  }

  if (resolveStepClass(refined, parseCalloutValue(refined?.source_callout)) === 'hole') {
    refined.analysis_type = 'aruco_2d';
    refined.measurement_mode = 'hole_diameter';
    refined.unit = 'mm';
  }

  if (resolveStepClass(refined, parseCalloutValue(refined?.source_callout)) === 'thickness') {
    refined.required_view = 'profile';
    refined.analysis_type = 'aruco_2d';
    refined.unit = 'mm';
  }

  refined = normalizeChamferWording(refined);
  return refined;
}

function hasFoldContext(rawStep) {
  return resolveStepClass(rawStep, parseCalloutValue(rawStep.source_callout)) === 'bend';
}

function normalizeStep(rawStep, index) {
  const callout = parseCalloutValue(rawStep.source_callout);
  const evidenceText = buildStepEvidenceText(rawStep);
  let stepClass = resolveStepClass(rawStep, callout);
  const rawAnalysisType = normalizeString(rawStep.analysis_type, 'aruco_2d').toLowerCase();
  let analysisType = rawAnalysisType === 'angle_profile' ? 'angle_profile' : 'aruco_2d';

  const hasBendEvidence = hasBendKeyword(evidenceText);
  const standaloneAngle =
    extractStandaloneAngleValue(rawStep?.source_callout) ??
    extractStandaloneAngleValue(rawStep?.target_hint) ??
    extractStandaloneAngleValue(rawStep?.title) ??
    extractStandaloneAngleValue(rawStep?.instruction);
  const hasAngleCallout = callout?.kind === 'angle' || standaloneAngle !== null;

  if (callout?.kind === 'chamfer') {
    stepClass = 'chamfer';
  } else if (callout?.kind === 'hole') {
    stepClass = 'hole';
  } else if (hasAngleCallout && hasBendEvidence) {
    stepClass = 'bend';
  }

  const expectedFromStep = normalizeNumber(rawStep.expected_value, 0);
  let expectedValue = callout?.value > 0 ? callout.value : expectedFromStep;
  if (expectedValue <= 0) {
    expectedValue = expectedFromStep;
  }
  if (standaloneAngle && stepClass === 'bend') {
    expectedValue = standaloneAngle;
  }

  if (stepClass === 'thickness' && !isPlausibleThicknessValue(expectedValue)) {
    stepClass = 'height';
  }

  if (stepClass === 'hole' || stepClass === 'chamfer' || stepClass === 'base' || stepClass === 'height' || stepClass === 'u_cutout' || stepClass === 'thickness') {
    analysisType = 'aruco_2d';
  }

  if (stepClass === 'bend') {
    analysisType = hasAngleCallout ? 'angle_profile' : 'aruco_2d';
  }

  if (stepClass === 'other' && analysisType === 'angle_profile' && !hasBendEvidence) {
    analysisType = 'aruco_2d';
    stepClass = expectedValue > 20 ? 'height' : 'base';
  }

  if (analysisType === 'angle_profile' && (expectedValue <= 0 || expectedValue >= 180)) {
    analysisType = 'aruco_2d';
    if (stepClass === 'bend') {
      stepClass = expectedValue > 20 ? 'height' : 'base';
    }
  }

  const defaultUnit = analysisType === 'angle_profile' ? 'deg' : 'mm';
  const rawUnit = normalizeString(rawStep.unit, defaultUnit).toLowerCase();
  let unit = ['mm', 'deg'].includes(rawUnit) ? rawUnit : defaultUnit;
  if (analysisType === 'angle_profile') {
    unit = 'deg';
  } else {
    unit = 'mm';
  }

  if (stepClass === 'hole' || stepClass === 'chamfer' || stepClass === 'thickness' || stepClass === 'u_cutout') {
    unit = 'mm';
  }

  const defaultTolerance = defaultToleranceForStep(unit, expectedValue, stepClass);
  const tolerance = Math.max(0, normalizeNumber(rawStep.tolerance, defaultTolerance));

  const id = normalizeString(rawStep.id, `STEP_${index + 1}`);
  const title = normalizeString(rawStep.title, `Etapa ${index + 1}`);

  const defaultView =
    analysisType === 'angle_profile' || stepClass === 'thickness' || stepClass === 'bend'
      ? 'profile'
      : stepClass === 'u_cutout'
      ? 'detail'
      : 'top';

  const measurementFallback = defaultMeasurementMode(analysisType, stepClass);

  let measurementMode = normalizeMeasurementMode(
    rawStep.measurement_mode,
    analysisType,
    measurementFallback,
  );

  if (stepClass === 'hole') {
    measurementMode = 'hole_diameter';
  }

  let requiredView = normalizeView(rawStep.required_view, defaultView);
  if (analysisType === 'angle_profile' || stepClass === 'bend' || stepClass === 'thickness') {
    requiredView = 'profile';
  } else if (stepClass === 'height' && normalizeView(rawStep.required_view, defaultView) === 'profile') {
    requiredView = 'profile';
  }

  const instruction = normalizeString(rawStep.instruction, 'Capture a imagem conforme instrucoes da etapa.');
  const targetHint = normalizeString(rawStep.target_hint, title);
  const sourceCallout = normalizeString(rawStep.source_callout, '');
  const captureChecklist = Array.isArray(rawStep.capture_checklist)
    ? rawStep.capture_checklist.map((item) => normalizeString(item)).filter(Boolean)
    : [];

  const captureHints = buildStepCaptureHints(
    {
      required_view: requiredView,
      instruction,
      target_hint: targetHint,
      source_callout: sourceCallout,
    },
    stepClass,
  );

  return {
    id,
    title,
    instruction,
    required_view: requiredView,
    analysis_type: analysisType,
    measurement_mode: measurementMode,
    axis_preference: normalizeAxisPreference(rawStep.axis_preference, 'auto'),
    target_hint: targetHint,
    source_callout: sourceCallout,
    expected_value: expectedValue,
    tolerance,
    unit,
    step_class: stepClass,
    requires_all_markers:
      analysisType === 'aruco_2d'
        ? normalizeBool(rawStep.requires_all_markers, true)
        : normalizeBool(rawStep.requires_all_markers, false),
    capture_checklist: captureChecklist,
    hidden_feature_candidate: captureHints.hidden_feature_candidate,
    occlusion_risk: captureHints.occlusion_risk,
    recommended_capture_pose: captureHints.recommended_capture_pose,
    verification_focus: captureHints.verification_focus,
  };
}

function normalizePlan(rawPlan, options = {}) {
  const seedEntityLedger = normalizeEntityLedger(options.entityLedgerSeed || []);
  const extractedEntityLedger = normalizeEntityLedger(
    rawPlan?.entity_ledger || rawPlan?.entities || rawPlan?.callouts || rawPlan?.items || [],
  );
  let entityLedger = choosePreferredEntityLedger(extractedEntityLedger, seedEntityLedger);

  const rawSteps = Array.isArray(rawPlan?.steps) ? rawPlan.steps : [];
  let steps = rawSteps
    .map((step, index) => normalizeStep(step || {}, index))
    .map((step) => refineNormalizedStep(step));
  entityLedger = mergeLedgerWithFoundationalStepEvidence(entityLedger, steps);
  steps = filterUnsupportedSteps(steps, entityLedger);
  steps = augmentStepsWithEntityLedger(steps, entityLedger);
  steps = filterUnsupportedSteps(steps, entityLedger);

  const holeDetectedInSteps = steps.some(
    (step) =>
      resolveStepClass(step, parseCalloutValue(step?.source_callout)) === 'hole' ||
      step.measurement_mode === 'hole_diameter',
  );
  const bendDetectedInSteps = steps.some((step) => stepSuggestsPhysicalBend(step));

  const holeDetectedInLedger = entityLedger.some(
    (entity) =>
      normalizeEntityClass(entity.feature_class, entity.symbol_type, entity.literal, entity.evidence) === 'hole' &&
      isMeasurableLedgerEntity(entity),
  );
  const bendDetectedInLedger = entityLedger.some(
    (entity) =>
      normalizeEntityClass(entity.feature_class, entity.symbol_type, entity.literal, entity.evidence) === 'bend' &&
      isMeasurableLedgerEntity(entity),
  );

  const rawHasBends = normalizeBool(rawPlan?.geometry_check?.has_physical_bends_or_folds, false);
  const rawHasHoles = normalizeBool(rawPlan?.geometry_check?.has_circular_holes, false);
  const notesText = normalizeString(rawPlan?.notes, '');
  const hasNegativeBendClaim = /(sem\s+dobr|sem\s+dobra|without\s+bend)/i.test(notesText);
  const hasProfileStep = steps.some((step) => normalizeView(step.required_view, 'top') === 'profile');
  const hasProfileFeatureClass = steps.some((step) =>
    ['height', 'chamfer', 'u_cutout', 'thickness', 'bend'].includes(
      resolveStepClass(step, parseCalloutValue(step?.source_callout)),
    ),
  );
  const contextualBendHint =
    hasBendKeyword(notesText) && !hasNegativeBendClaim && hasProfileStep && hasProfileFeatureClass;

  const hasPhysicalBends = bendDetectedInSteps || bendDetectedInLedger || rawHasBends || contextualBendHint;
  const hasCircularHoles = holeDetectedInSteps || holeDetectedInLedger || rawHasHoles;

  return {
    geometry_check: {
      is_flat_plate: normalizeBool(rawPlan?.geometry_check?.is_flat_plate, true),
      has_physical_bends_or_folds: hasPhysicalBends,
      has_circular_holes: hasCircularHoles,
    },
    part_name: normalizePartName(
      rawPlan?.part_name,
      entityLedger.length ? 'Peca inferida por evidencias' : 'Peca sem nome',
    ),
    unit: normalizeString(rawPlan?.unit, 'mm'),
    notes: normalizePlanNotes(
      rawPlan?.notes,
      entityLedger.length ? 'Plano inferido a partir de evidencias tecnicas do desenho.' : '',
    ),
    entity_ledger: entityLedger,
    steps,
  };
}

function captureIntentForView(view, relatedClasses = []) {
  if (view === 'profile') {
    if (relatedClasses.includes('bend')) {
      return 'Validar dobras, espessura e angulos em perfil ortogonal.';
    }
    return 'Validar cotas em perfil (espessura/abas/recortes) com camera ortogonal.';
  }
  if (relatedClasses.includes('hole')) {
    return 'Validar diametros e posicoes de furos com foco em concentridade e oclusoes.';
  }
  if (view === 'detail') {
    return 'Captura de detalhe para geometria interna/recortes e arestas pequenas.';
  }
  return 'Validar cotas lineares da vista principal com enquadramento completo da peca.';
}

function capturePoseForView(view, relatedClasses = []) {
  if (view === 'profile') {
    return 'camera_perpendicular_to_profile';
  }
  if (view === 'detail') {
    return 'closeup_with_aruco_reference';
  }
  if (relatedClasses.includes('hole')) {
    return 'top_view_centered_on_hole_axis';
  }
  return 'camera_perpendicular_to_surface';
}

function buildFramingChecklist(view, relatedClasses = [], hiddenFeatureFocus = false) {
  const checklist = ['manter 4 ArUco visiveis e no mesmo plano'];

  if (view === 'profile') {
    checklist.push('alinhar camera a 90 graus com o perfil da peca');
  }
  if (relatedClasses.includes('hole')) {
    checklist.push('centralizar furo e borda de referencia no enquadramento');
  }
  if (relatedClasses.includes('chamfer')) {
    checklist.push('destacar aresta chanfrada sem sombra forte');
  }
  if (hiddenFeatureFocus) {
    checklist.push('se houver oclusao, capturar foto complementar do lado oposto');
  }

  return checklist;
}

function summarizeCapturePlan(plan) {
  const byView = {
    top: 0,
    profile: 0,
    front: 0,
    isometric: 0,
    detail: 0,
  };

  for (const step of plan.steps) {
    const normalizedView = normalizeView(step.required_view, 'top');
    if (!Object.hasOwn(byView, normalizedView)) {
      byView[normalizedView] = 0;
    }
    byView[normalizedView] += 1;
  }

  const requiredPhotos = Object.entries(byView)
    .filter(([, count]) => count > 0)
    .map(([view, count], index) => {
      const relatedSteps = plan.steps.filter((s) => normalizeView(s.required_view, 'top') === view);
      const relatedClasses = [
        ...new Set(
          relatedSteps.map((s) => resolveStepClass(s, parseCalloutValue(s?.source_callout))),
        ),
      ];
      const hiddenFeatureFocus = relatedSteps.some(
        (s) =>
          s.hidden_feature_candidate ||
          ['hole', 'bend', 'u_cutout'].includes(resolveStepClass(s, parseCalloutValue(s?.source_callout))),
      );
      const occlusionRisk =
        relatedClasses.includes('bend') || (relatedClasses.includes('hole') && view !== 'top')
          ? 'high'
          : hiddenFeatureFocus
          ? 'medium'
          : 'low';

      return {
        photo_id: `PHOTO_${index + 1}`,
        view,
        minimum_shots: clamp(count, 1, 5),
        intent: captureIntentForView(view, relatedClasses),
        related_steps: relatedSteps.map((s) => s.id),
        related_classes: relatedClasses,
        camera_pose: capturePoseForView(view, relatedClasses),
        hidden_feature_focus: hiddenFeatureFocus,
        occlusion_risk: occlusionRisk,
        must_include_reverse_side: hiddenFeatureFocus,
        framing_checklist: buildFramingChecklist(view, relatedClasses, hiddenFeatureFocus),
      };
    });

  const hasBend = plan.steps.some(
    (s) => resolveStepClass(s, parseCalloutValue(s?.source_callout)) === 'bend',
  );
  const hasHole = plan.steps.some(
    (s) => resolveStepClass(s, parseCalloutValue(s?.source_callout)) === 'hole',
  );

  if (hasBend) {
    requiredPhotos.push({
      photo_id: `PHOTO_${requiredPhotos.length + 1}`,
      view: 'profile',
      minimum_shots: 1,
      intent: 'Capturar perfil oposto para confirmar dobras e possiveis oclusoes.',
      related_steps: plan.steps
        .filter((s) => resolveStepClass(s, parseCalloutValue(s?.source_callout)) === 'bend')
        .map((s) => s.id),
      related_classes: ['bend', 'thickness'],
      camera_pose: 'camera_perpendicular_to_profile',
      hidden_feature_focus: true,
      occlusion_risk: 'high',
      must_include_reverse_side: true,
      framing_checklist: [
        'capturar lado oposto ao perfil principal',
        'manter linha de dobra completa e em foco',
        'preservar referencia de escala (ArUco)',
      ],
    });
  }

  if (hasHole && (hasBend || byView.detail === 0)) {
    requiredPhotos.push({
      photo_id: `PHOTO_${requiredPhotos.length + 1}`,
      view: 'detail',
      minimum_shots: 1,
      intent: 'Detalhar furos em areas potencialmente ocultas por abas/dobras.',
      related_steps: plan.steps
        .filter((s) => resolveStepClass(s, parseCalloutValue(s?.source_callout)) === 'hole')
        .map((s) => s.id),
      related_classes: ['hole'],
      camera_pose: 'closeup_with_aruco_reference',
      hidden_feature_focus: true,
      occlusion_risk: 'high',
      must_include_reverse_side: true,
      framing_checklist: [
        'aproximar da regiao dos furos mantendo escala visivel',
        'verificar furo passante em pelo menos duas vistas',
      ],
    });
  }

  const photoViewsSummary = {
    top: 0,
    profile: 0,
    front: 0,
    isometric: 0,
    detail: 0,
  };

  for (const photo of requiredPhotos) {
    if (!Object.hasOwn(photoViewsSummary, photo.view)) {
      photoViewsSummary[photo.view] = 0;
    }
    photoViewsSummary[photo.view] += 1;
  }

  return {
    strategy: 'multi_view_guided_capture',
    requires_multi_view: requiredPhotos.length > 1,
    views_summary: byView,
    photo_views_summary: photoViewsSummary,
    hidden_feature_risk: {
      has_hidden_features: hasBend || hasHole,
      high_risk_classes: ['bend', 'hole'].filter((cls) =>
        plan.steps.some((s) => resolveStepClass(s, parseCalloutValue(s?.source_callout)) === cls),
      ),
      recommendation: hasBend || hasHole
        ? 'Executar capturas complementares em perfil e detalhe para evitar falso negativo.'
        : 'Captura padrao suficiente para o desenho informado.',
    },
    required_photos: requiredPhotos,
  };
}

function median(values, fallback = 0) {
  if (!values.length) {
    return fallback;
  }
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
  return sorted[middle];
}

function mostFrequent(items, fallback = '') {
  if (!items.length) {
    return fallback;
  }
  const frequency = new Map();
  for (const item of items) {
    frequency.set(item, (frequency.get(item) || 0) + 1);
  }

  let best = fallback;
  let bestCount = -1;
  for (const [item, count] of frequency.entries()) {
    if (count > bestCount) {
      best = item;
      bestCount = count;
    }
  }
  return best;
}

function stepSignature(step) {
  const stepClass = resolveStepClass(step, parseCalloutValue(step.source_callout));
  const mode = normalizeString(step.measurement_mode, '');
  const source = normalizeString(step.source_callout, '').replace(/\s+/g, '').toLowerCase();
  if (source) {
    return `${stepClass}|${step.analysis_type}|${mode}|${source}`;
  }

  const target = normalizeString(step.target_hint, '').replace(/\s+/g, '').toLowerCase();
  const expected = Number(step.expected_value || 0).toFixed(3);
  return `${stepClass}|${step.analysis_type}|${mode}|${target}|${expected}`;
}

function hasLiteralMeasurementEvidence(step) {
  const source = normalizeString(step.source_callout, '');
  if (!source) {
    return false;
  }

  if (parseCalloutValue(source)?.value > 0) {
    return true;
  }

  return /(ø|phi|diam|diametro|raio|r\d+)/i.test(source);
}

function enforceGeometricConsistency(plan) {
  const issues = [];
  const steps = plan.steps || [];
  const coverage = analyzeClassCoverage(plan);
  const entityLedger = Array.isArray(plan.entity_ledger) ? plan.entity_ledger : [];
  const measurableEntities = entityLedger.filter(
    (entity) =>
      isMeasurableLedgerEntity(entity) && normalizeNumber(entity.confidence, 0) >= MIN_LEDGER_ENTITY_CONFIDENCE,
  );
  const mappedEntityKeys = new Set();

  const angleSteps = steps.filter((s) => s.analysis_type === 'angle_profile');
  const holeSteps = steps.filter((s) => s.measurement_mode === 'hole_diameter');
  const holeEvidenceSteps = steps.filter((s) => parseCalloutValue(s.source_callout)?.kind === 'hole');
  const bendEvidenceSteps = steps.filter(
    (s) => resolveStepClass(s, parseCalloutValue(s?.source_callout)) === 'bend',
  );
  const duplicateStepIds = findDuplicateStepIds(steps);
  const measurableBendEvidence = hasMeasurableBendEvidence(plan);

  if (hasNotesContradiction(plan.notes)) {
    issues.push({
      code: 'CONTRADICTORY_NOTES',
      severity: 'major',
      message: 'Campo notes contem afirmacoes contraditorias.',
    });
  }

  for (const duplicatedId of duplicateStepIds) {
    issues.push({
      code: 'DUPLICATE_STEP_ID',
      severity: 'critical',
      step_id: duplicatedId,
      message: 'ID de etapa repetido; todos os steps devem ter IDs unicos.',
    });
  }

  const signatureCounts = new Map();
  for (const step of steps) {
    const stepClass = resolveStepClass(step, parseCalloutValue(step.source_callout));
    const source = normalizeString(step.source_callout, '').replace(/\s+/g, '').toLowerCase();
    if (!source || stepClass === 'other') {
      continue;
    }
    const key = `${stepClass}|${source}`;
    signatureCounts.set(key, (signatureCounts.get(key) || 0) + 1);
  }

  for (const [signature, count] of signatureCounts.entries()) {
    if (count <= 1) {
      continue;
    }
    issues.push({
      code: 'DUPLICATE_MEASUREMENT_SIGNATURE',
      severity: 'major',
      message: `Etapas repetidas para a mesma cota/classe (${signature}).`,
    });
  }

  if (plan.geometry_check.has_physical_bends_or_folds && measurableBendEvidence && angleSteps.length === 0) {
    issues.push({
      code: 'MISSING_FOLD_STEP',
      severity: 'critical',
      message: 'Geometry indica dobra fisica, mas nao ha etapa angle_profile.',
    });
  }

  if (plan.geometry_check.has_circular_holes && holeSteps.length === 0) {
    issues.push({
      code: 'MISSING_HOLE_STEP',
      severity: 'major',
      message: 'Geometry indica furos, mas nao ha etapa com measurement_mode hole_diameter.',
    });
  }

  if (!plan.geometry_check.has_circular_holes && holeEvidenceSteps.length > 0) {
    issues.push({
      code: 'GEOMETRY_HOLE_CONTRADICTION',
      severity: 'critical',
      message: 'Há evidencia de furo nas etapas, mas geometry_check.has_circular_holes esta false.',
    });
  }

  if (!plan.geometry_check.has_physical_bends_or_folds && bendEvidenceSteps.length > 0) {
    issues.push({
      code: 'GEOMETRY_BEND_CONTRADICTION',
      severity: 'major',
      message: 'Há evidencia de dobra nas etapas, mas geometry_check.has_physical_bends_or_folds esta false.',
    });
  }

  for (const step of steps) {
    const callout = parseCalloutValue(step.source_callout);
    const stepClass = resolveStepClass(step, callout);

    if (entityLedger.length > 0 && step.source_callout) {
      const matchedEntity = findMatchingEntityForStep(step, entityLedger);
      if (matchedEntity) {
        mappedEntityKeys.add(`${matchedEntity.feature_class}|${entityLiteralKey(matchedEntity.literal)}`);
      } else if (LEDGER_STRICT_MAPPING) {
        issues.push({
          code: 'STEP_CALLOUT_NOT_IN_LEDGER',
          severity: 'major',
          step_id: step.id,
          message: 'source_callout da etapa nao foi confirmado no entity_ledger.',
        });
      }
    }

    if (!step.source_callout) {
      issues.push({
        code: 'STEP_WITHOUT_SOURCE_CALLOUT',
        severity: 'major',
        step_id: step.id,
        message: 'Etapa sem source_callout literal da cota do desenho.',
      });
    }

    if (step.analysis_type === 'angle_profile' && step.unit !== 'deg') {
      issues.push({
        code: 'ANGLE_WITH_WRONG_UNIT',
        severity: 'critical',
        step_id: step.id,
        message: 'Etapa angular deve ter unit deg.',
      });
    }

    if (step.analysis_type === 'aruco_2d' && step.unit !== 'mm') {
      issues.push({
        code: 'LINEAR_WITH_WRONG_UNIT',
        severity: 'critical',
        step_id: step.id,
        message: 'Etapa linear deve ter unit mm.',
      });
    }

    if (step.analysis_type === 'angle_profile' && (step.expected_value <= 0 || step.expected_value >= 180)) {
      issues.push({
        code: 'ANGLE_OUT_OF_RANGE',
        severity: 'critical',
        step_id: step.id,
        message: 'Angulo esperado deve estar entre 0 e 180 graus.',
      });
    }

    if (step.analysis_type === 'aruco_2d' && step.expected_value <= 0) {
      issues.push({
        code: 'NON_POSITIVE_LINEAR',
        severity: 'critical',
        step_id: step.id,
        message: 'Medida linear esperada deve ser positiva.',
      });
    }

    if (callout && callout.value > 0) {
      const deviation = Math.abs(step.expected_value - callout.value);
      if (deviation > 0.001) {
        issues.push({
          code: 'CALLOUT_VALUE_MISMATCH',
          severity: 'major',
          step_id: step.id,
          message: 'expected_value diverge da cota literal em source_callout.',
        });
      }
    }

    const chamferPattern = /(\d+(?:[.,]\d+)?)\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*(?:deg|°|grau|graus)/i;
    if (chamferPattern.test(step.source_callout) && step.analysis_type === 'angle_profile') {
      issues.push({
        code: 'CHAMFER_CLASSIFIED_AS_BEND',
        severity: 'critical',
        step_id: step.id,
        message: 'Cota Nx45 foi tratada como dobra angular e deve ser linear.',
      });
    }

    if (chamferPattern.test(step.source_callout) && stepClass === 'bend') {
      issues.push({
        code: 'CHAMFER_LABELED_AS_BEND',
        severity: 'critical',
        step_id: step.id,
        message: 'Cota Nx45 foi rotulada como dobra em titulo/instrucao/checklist.',
      });
    }

    if (callout?.kind === 'hole' && step.measurement_mode !== 'hole_diameter') {
      issues.push({
        code: 'HOLE_WITH_WRONG_MEASUREMENT_MODE',
        severity: 'major',
        step_id: step.id,
        message: 'Etapa de furo deve usar measurement_mode hole_diameter.',
      });
    }

    if (stepClass === 'thickness' && step.required_view !== 'profile') {
      issues.push({
        code: 'THICKNESS_WITH_WRONG_VIEW',
        severity: 'major',
        step_id: step.id,
        message: 'Espessura deve priorizar required_view profile.',
      });
    }
  }

  for (const entity of measurableEntities) {
    const mappingKey = `${entity.feature_class}|${entityLiteralKey(entity.literal)}`;
    if (mappedEntityKeys.has(mappingKey)) {
      continue;
    }
    issues.push({
      code: 'UNMAPPED_MEASURABLE_ENTITY',
      severity: 'major',
      class_name: entity.feature_class,
      message: `Evidencia mensuravel sem etapa associada: ${entity.literal}`,
    });
  }

  for (const missingClass of coverage.missing_required_classes) {
    issues.push({
      code: 'MISSING_REQUIRED_CLASS',
      severity: 'major',
      class_name: missingClass,
      message: `Plano sem cobertura da classe obrigatoria ${humanizeClassName(missingClass)}.`,
    });
  }

  return issues;
}

function scorePlanQuality(plan, ensembleAgreement = 1) {
  let confidence = 1.0;
  const issues = enforceGeometricConsistency(plan);
  const coverage = analyzeClassCoverage(plan);
  const measurableEvidenceCount = normalizeNumber(coverage.evidence_measurable_entities, 0);

  if (plan.steps.length === 0) {
    confidence -= 0.8;
  }

  if (plan.steps.length > 0 && plan.steps.length < 4 && measurableEvidenceCount > 2) {
    issues.push({
      code: 'TOO_FEW_STEPS',
      severity: 'major',
      message: 'Plano com poucas etapas para um desenho tecnico tipico; cobertura pode estar incompleta.',
    });
    confidence -= 0.2;
  }

  const majorIssues = issues.filter((i) => i.severity === 'major').length;
  const criticalIssues = issues.filter((i) => i.severity === 'critical').length;
  const duplicateIdIssues = issues.filter((i) => i.code === 'DUPLICATE_STEP_ID').length;
  const contradictionIssues = issues.filter((i) => normalizeString(i.code, '').includes('CONTRADICTION')).length;

  confidence -= majorIssues * 0.08;
  confidence -= criticalIssues * 0.16;
  confidence -= Math.min(0.5, duplicateIdIssues * 0.2);
  confidence -= Math.min(0.3, contradictionIssues * 0.15);

  const missingRequiredPenalty = coverage.missing_required_classes.length * 0.12;
  const missingFocusPenalty =
    measurableEvidenceCount > 3 ? Math.min(0.12, coverage.missing_focus_classes.length * 0.02) : 0;
  confidence -= missingRequiredPenalty;
  confidence -= missingFocusPenalty;

  const missingSource = plan.steps.filter((s) => !s.source_callout).length;
  confidence -= Math.min(0.2, missingSource * 0.03);

  confidence -= (1 - ensembleAgreement) * 0.25;
  confidence = clamp(confidence, 0, 1);

  let status = confidence >= STRICT_MIN_CONFIDENCE ? 'high' : confidence >= 0.65 ? 'medium' : 'low';
  if (criticalIssues > 0 || duplicateIdIssues > 0 || contradictionIssues > 0) {
    status = 'low';
  }

  const mustReject =
    criticalIssues > 0 ||
    duplicateIdIssues > 0 ||
    contradictionIssues > 0 ||
    coverage.missing_required_classes.length > 0 ||
    confidence < STRICT_MIN_CONFIDENCE;

  return {
    confidence,
    ensemble_agreement: ensembleAgreement,
    status,
    issues,
    coverage,
    must_reject: mustReject,
  };
}

function mergeEntityLedgers(plans = []) {
  const grouped = new Map();

  for (const plan of plans) {
    const ledger = Array.isArray(plan?.entity_ledger) ? plan.entity_ledger : [];
    for (const entity of ledger) {
      const key = `${normalizeString(entity.feature_class, 'other')}|${normalizeString(entity.symbol_type, 'unknown')}|${entityLiteralKey(entity.literal)}`;
      if (!grouped.has(key)) {
        grouped.set(key, []);
      }
      grouped.get(key).push(entity);
    }
  }

  const merged = [];
  for (const entries of grouped.values()) {
    const exemplar = entries[0];
    const confidenceValues = entries.map((entity) => normalizeNumber(entity.confidence, 0.5));
    const primaryValues = entries
      .map((entity) => normalizeNumber(entity.primary_value, 0))
      .filter((value) => Number.isFinite(value) && value > 0);
    const secondaryValues = entries
      .map((entity) => normalizeNumber(entity.secondary_value, 0))
      .filter((value) => Number.isFinite(value) && value > 0);
    const quantityValues = entries
      .map((entity) => normalizeNumber(entity.quantity, 1))
      .filter((value) => Number.isFinite(value) && value > 0);

    merged.push({
      ...exemplar,
      primary_value: primaryValues.length ? median(primaryValues, normalizeNumber(exemplar.primary_value, 0)) : normalizeNumber(exemplar.primary_value, 0),
      secondary_value: secondaryValues.length
        ? median(secondaryValues, normalizeNumber(exemplar.secondary_value, 0))
        : normalizeNumber(exemplar.secondary_value, 0),
      quantity: Math.max(1, Math.round(quantityValues.length ? median(quantityValues, 1) : normalizeNumber(exemplar.quantity, 1))),
      confidence: clamp(median(confidenceValues, 0.5), 0, 1),
      evidence: mostFrequent(entries.map((entity) => normalizeString(entity.evidence, '')), normalizeString(exemplar.evidence, '')),
      view_hint: mostFrequent(entries.map((entity) => normalizeString(entity.view_hint, 'unknown')), normalizeString(exemplar.view_hint, 'unknown')),
      orientation_hint: mostFrequent(entries.map((entity) => normalizeString(entity.orientation_hint, 'unknown')), normalizeString(exemplar.orientation_hint, 'unknown')),
    });
  }

  return merged
    .sort((left, right) => normalizeNumber(right.confidence, 0) - normalizeNumber(left.confidence, 0))
    .slice(0, LEDGER_MAX_ENTITIES)
    .map((entity, index) => ({
      ...entity,
      id: `ENT_${index + 1}`,
    }));
}

function mergePlanEnsemble(plans) {
  if (!plans.length) {
    return {
      mergedPlan: normalizePlan({}),
      diagnostics: {
        ensemble_size: 0,
        selected_steps: 0,
        agreement_ratio: 0,
      },
    };
  }

  if (plans.length === 1) {
    const singlePlan = normalizePlan(plans[0], { entityLedgerSeed: plans[0]?.entity_ledger || [] });
    singlePlan.steps = augmentStepsWithEntityLedger(singlePlan.steps, singlePlan.entity_ledger || []);
    singlePlan.steps = filterUnsupportedSteps(singlePlan.steps, singlePlan.entity_ledger || []);
    return {
      mergedPlan: singlePlan,
      diagnostics: {
        ensemble_size: 1,
        selected_steps: singlePlan.steps.length,
        total_candidate_steps: singlePlan.steps.length,
        agreement_ratio: 1,
      },
    };
  }

  const grouped = new Map();
  let totalCandidateSteps = 0;

  for (const plan of plans) {
    for (const step of plan.steps) {
      totalCandidateSteps += 1;
      const key = stepSignature(step);
      if (!grouped.has(key)) {
        grouped.set(key, []);
      }
      grouped.get(key).push(step);
    }
  }

  const mergedSteps = [];

  for (const steps of grouped.values()) {
    const count = steps.length;
    const keepThreshold = plans.length <= 3 ? 2 : Math.max(2, Math.ceil(plans.length / 2));
    const exemplar = steps[0];
    const rescuedSingleton = count === 1 && plans.length <= 3 && hasLiteralMeasurementEvidence(exemplar);

    if (count < keepThreshold && !rescuedSingleton) {
      continue;
    }

    const expectedValues = steps.map((s) => normalizeNumber(s.expected_value, 0)).filter((v) => v > 0);
    const tolerances = steps.map((s) => normalizeNumber(s.tolerance, 0.5)).filter((v) => v > 0);

    mergedSteps.push({
      ...exemplar,
      expected_value: expectedValues.length ? median(expectedValues, exemplar.expected_value) : exemplar.expected_value,
      tolerance: tolerances.length ? median(tolerances, exemplar.tolerance) : exemplar.tolerance,
      capture_checklist: mostFrequent(steps.map((s) => JSON.stringify(s.capture_checklist)), '[]'),
      _votes: count,
    });
  }

  mergedSteps.sort((a, b) => b._votes - a._votes);
  const normalizedSteps = mergedSteps.map((step, index) => {
    const normalized = normalizeStep(
      {
        ...step,
        id: normalizeString(step.id, `STEP_${index + 1}`),
        capture_checklist: JSON.parse(step.capture_checklist || '[]'),
      },
      index,
    );
    return refineNormalizedStep(normalized);
  });

  const mergedEntityLedger = mergeEntityLedgers(plans);
  const evidenceAugmentedSteps = filterUnsupportedSteps(
    augmentStepsWithEntityLedger(normalizedSteps, mergedEntityLedger),
    mergedEntityLedger,
  );

  const mergedPlan = {
    geometry_check: {
      is_flat_plate: plans.filter((p) => p.geometry_check.is_flat_plate).length >= Math.ceil(plans.length / 2),
      has_physical_bends_or_folds:
        plans.filter((p) => p.geometry_check.has_physical_bends_or_folds).length >= Math.ceil(plans.length / 2),
      has_circular_holes: plans.filter((p) => p.geometry_check.has_circular_holes).length >= Math.ceil(plans.length / 2),
    },
    part_name: normalizePartName(
      mostFrequent(plans.map((p) => p.part_name), plans[0].part_name),
      'Peca inferida por evidencias',
    ),
    unit: 'mm',
    notes: normalizePlanNotes(
      mostFrequent(plans.map((p) => normalizeString(p.notes, '')), ''),
      `Plano consolidado por consenso de ${plans.length} analises independentes.`,
    ),
    entity_ledger: mergedEntityLedger,
    steps: evidenceAugmentedSteps,
  };

  const agreementRatio = totalCandidateSteps > 0 ? evidenceAugmentedSteps.length / totalCandidateSteps : 0;

  return {
    mergedPlan,
    diagnostics: {
      ensemble_size: plans.length,
      selected_steps: evidenceAugmentedSteps.length,
      total_candidate_steps: totalCandidateSteps,
      agreement_ratio: clamp(agreementRatio * plans.length, 0, 1),
    },
  };
}

function serializeLedgerForPrompt(entityLedger = [], maxItems = 80) {
  const simplified = (entityLedger || []).slice(0, Math.min(LEDGER_MAX_ENTITIES, maxItems)).map((entity) => ({
    id: entity.id,
    literal: entity.literal,
    symbol_type: entity.symbol_type,
    feature_class: entity.feature_class,
    primary_value: entity.primary_value,
    quantity: entity.quantity,
    unit: entity.unit,
    view_hint: entity.view_hint,
    orientation_hint: entity.orientation_hint,
    confidence: normalizeNumber(entity.confidence, 0),
  }));
  return JSON.stringify(simplified);
}

function serializePlanForRecovery(seedPlan = {}, maxSteps = 24) {
  const compactSteps = (Array.isArray(seedPlan?.steps) ? seedPlan.steps : []).slice(0, maxSteps).map((step) => ({
    id: step.id,
    source_callout: step.source_callout,
    step_class: step.step_class,
    analysis_type: step.analysis_type,
    required_view: step.required_view,
    expected_value: step.expected_value,
    unit: step.unit,
  }));

  return JSON.stringify({
    geometry_check: seedPlan?.geometry_check || {},
    part_name: seedPlan?.part_name || '',
    unit: seedPlan?.unit || 'mm',
    notes: seedPlan?.notes || '',
    steps: compactSteps,
  });
}

function applyReasoningThenJsonProtocol(promptBody, schemaHint = 'the required JSON schema', options = {}) {
  const forceJsonOnly = normalizeBool(options.forceJsonOnly, false);
  if (forceJsonOnly || !ENABLE_REASONING_THEN_JSON) {
    return `${promptBody}\n\nReturn ONLY valid JSON. Do not output reasoning, comments, markdown fences, or extra wrapper text.`;
  }

  return `${promptBody}

Response protocol (strict):
1) First output CHAIN_OF_THOUGHT with concise numbered reasoning steps.
2) Then output ${FINAL_JSON_START_MARKER} on its own line.
3) Then output exactly one valid JSON object following ${schemaHint}.
4) Then output ${FINAL_JSON_END_MARKER} on its own line.
5) Do not use markdown code fences.
6) Do not output any text after ${FINAL_JSON_END_MARKER}.`;
}

function buildLedgerExtractionPrompt() {
  return applyReasoningThenJsonProtocol(LEDGER_EXTRACTION_PROMPT, 'the entity_ledger schema above');
}

function buildLedgerRecallPrompt(seedLedger = []) {
  const seedJson = serializeLedgerForPrompt(seedLedger, 80);
  const promptBody = `${LEDGER_EXTRACTION_PROMPT}

CURRENT PARTIAL ENTITY_LEDGER:
${seedJson}

Additional recall task:
- Re-scan the image and add missing visible dimensions (internal/external linear dimensions, height, thickness, Ø, Nx45, cutouts).
- Keep already detected dimensions and include new ones without duplicates.
- If uncertain, keep lower confidence instead of omitting entities.
- When clearly visible, include at least one overall horizontal envelope dimension and one overall vertical envelope dimension.

Return the updated entity_ledger.`;

  return applyReasoningThenJsonProtocol(promptBody, 'the entity_ledger schema above');
}

function hasMeasurableClassInLedger(entityLedger = [], className = '') {
  const targetClass = normalizeString(className, '').toLowerCase();
  if (!targetClass) {
    return false;
  }

  return (entityLedger || []).some((entity) => {
    if (normalizeNumber(entity?.confidence, 0) < MIN_LEDGER_ENTITY_CONFIDENCE) {
      return false;
    }
    if (!isMeasurableLedgerEntity(entity)) {
      return false;
    }

    const normalizedClass = normalizeEntityClass(
      entity.feature_class,
      entity.symbol_type,
      entity.literal,
      entity.evidence,
      entity.orientation_hint,
    );
    return normalizedClass === targetClass;
  });
}

function getMissingEnvelopeRecallClasses(entityLedger = []) {
  const summary = summarizeEntityLedger(entityLedger || []);
  const measurable = normalizeNumber(summary.measurable_entities, 0);
  if (measurable < 2) {
    return [];
  }

  const hasBase = hasMeasurableClassInLedger(entityLedger, 'base');
  const hasHeight = hasMeasurableClassInLedger(entityLedger, 'height');

  if (hasBase === hasHeight) {
    return [];
  }

  return ENVELOPE_FOUNDATIONAL_CLASSES.filter((item) => !hasMeasurableClassInLedger(entityLedger, item));
}

function buildMissingClassRecallPrompt(seedLedger = [], missingClasses = [], options = {}) {
  const seedJson = serializeLedgerForPrompt(seedLedger, 80);
  const missingText = missingClasses.map((item) => humanizeClassName(item)).join(', ');
  const classHints = [];

  if (missingClasses.includes('height')) {
    classHints.push(
      '- Focus on vertical envelope dimensions (overall height, flange/leg vertical span, top-to-bottom references) when explicitly visible.',
    );
    classHints.push(
      '- For each recovered height candidate, set orientation_hint to vertical whenever the callout direction is vertical.',
    );
    classHints.push(
      '- Do not collapse distinct literals (for example 55 and 65) into a single value; keep each visible literal as a separate entity.',
    );
  }
  if (missingClasses.includes('base')) {
    classHints.push(
      '- Focus on horizontal envelope dimensions (overall base/length/width span) when explicitly visible.',
    );
    classHints.push(
      '- For each recovered base candidate, set orientation_hint to horizontal whenever the callout direction is horizontal.',
    );
  }

  const promptBody = `${LEDGER_EXTRACTION_PROMPT}

TARGETED CLASS RECALL:
- Missing foundational classes: ${missingText}

CURRENT ENTITY_LEDGER:
${seedJson}

Targeted instructions:
${classHints.join('\n')}
- Do not reinterpret chamfer literals (Nx45) as bends.
- Keep all existing valid entities and add only clearly visible missing dimensions.
- For linear entities, infer orientation_hint whenever possible instead of using unknown/auto.

Return the updated entity_ledger.`;

  return applyReasoningThenJsonProtocol(promptBody, 'the entity_ledger schema above', options);
}

function buildSpecializedPrompt(passIndex, entityLedger = [], options = {}) {
  const hasLedger = Array.isArray(entityLedger) && entityLedger.length > 0;
  const ledgerJson = hasLedger ? serializeLedgerForPrompt(entityLedger, 60) : '[]';

  const specializations = [
    'Specialization A: outer contour linear dimensions and height coverage.',
    'Specialization B: holes, Nx45 chamfers, and internal cutouts.',
    'Specialization C: thickness/profile and anti-hallucination audit.',
  ];
  const specialization = specializations[passIndex % specializations.length];

  const ledgerClause = hasLedger
    ? `
BASE ENTITY_LEDGER:
${ledgerJson}

Use the ledger as baseline and prioritize covering its dimensions with valid steps.`
    : '\nNo reliable ledger is available: extract dimensions first, then build steps.';

  const promptBody = `${BASE_PROMPT}${ledgerClause}\n\n${specialization}\n\nPrioritize complete, non-contradictory coverage of visible measurable dimensions.`;
  return applyReasoningThenJsonProtocol(promptBody, 'the inspection plan schema above', options);
}

function buildRecoveryPrompt(seedPlan, coverage = null, entityLedger = []) {
  const seedJson = serializePlanForRecovery(seedPlan);
  const ledgerJson = serializeLedgerForPrompt(entityLedger, 80);
  const missingRequired = coverage?.missing_required_classes || [];
  const missingFocus = coverage?.missing_focus_classes || [];
  const prioritized = [...new Set([...missingRequired, ...missingFocus.slice(0, 3)])];
  const prioritizedText = prioritized.length
    ? prioritized.map((item) => humanizeClassName(item)).join(', ')
    : 'no specific missing category';

  const promptBody = `${BASE_PROMPT}

Review the image again and improve coverage/coherence.
Current plan summary:
${seedJson}

Reference entity ledger:
${ledgerJson}

Revision goals:
1. Keep valid steps from the current plan.
2. Add missing steps for visible ledger dimensions.
3. Prioritize: ${prioritizedText}.
4. Do not invent invisible dimensions or non-existent source_callout values.
5. Every step must include a literal source_callout.

Return a corrected inspection plan.`;

  return applyReasoningThenJsonProtocol(promptBody, 'the same inspection plan schema');
}

function stripJsonCodeFence(text) {
  return normalizeString(text, '')
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```\s*$/i, '')
    .trim();
}

function scoreJsonCandidatePayload(payload) {
  if (payload === null || payload === undefined) {
    return -1;
  }

  if (Array.isArray(payload)) {
    return payload.length > 0 ? 4 : 1;
  }

  if (typeof payload !== 'object') {
    return -1;
  }

  let score = 2;
  if (Array.isArray(payload.entity_ledger)) {
    score += 8;
  }
  if (Array.isArray(payload.steps)) {
    score += 8;
  }
  if (payload.geometry_check && typeof payload.geometry_check === 'object') {
    score += 4;
  }
  if (payload.drawing_context && typeof payload.drawing_context === 'object') {
    score += 3;
  }
  if (Array.isArray(payload.entities) || Array.isArray(payload.callouts) || Array.isArray(payload.items)) {
    score += 3;
  }
  if (Object.keys(payload).length >= 3) {
    score += 1;
  }

  return score;
}

function extractJsonPayload(rawText) {
  const text = normalizeString(rawText, '');
  if (!text) {
    throw new Error('Resposta da IA veio vazia.');
  }

  const normalized = text.trim();
  const candidateTexts = [];

  const pushCandidate = (value) => {
    const cleaned = stripJsonCodeFence(value);
    if (cleaned) {
      candidateTexts.push(cleaned);
    }
  };

  const markerRegex = new RegExp(
    `${FINAL_JSON_START_MARKER}\\s*([\\s\\S]*?)\\s*${FINAL_JSON_END_MARKER}`,
    'i',
  );
  const markerMatch = normalized.match(markerRegex);
  if (markerMatch?.[1]) {
    pushCandidate(markerMatch[1]);
  }

  const xmlJsonMatch = normalized.match(/<final_json>([\s\S]*?)<\/final_json>/i);
  if (xmlJsonMatch?.[1]) {
    pushCandidate(xmlJsonMatch[1]);
  }

  const fencedBlocks = [...normalized.matchAll(/```(?:json)?\s*([\s\S]*?)```/gi)];
  for (const block of fencedBlocks) {
    if (block?.[1]) {
      pushCandidate(block[1]);
    }
  }

  pushCandidate(normalized);

  const balancedSource = stripJsonCodeFence(normalized);
  let inString = false;
  let escaping = false;
  const stack = [];
  let start = -1;

  for (let i = 0; i < balancedSource.length; i += 1) {
    const char = balancedSource[i];

    if (inString) {
      if (escaping) {
        escaping = false;
        continue;
      }
      if (char === '\\') {
        escaping = true;
        continue;
      }
      if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === '{' || char === '[') {
      if (stack.length === 0) {
        start = i;
      }
      stack.push(char);
      continue;
    }

    if (char === '}' || char === ']') {
      if (stack.length === 0) {
        continue;
      }

      const opener = stack.pop();
      const validPair = (opener === '{' && char === '}') || (opener === '[' && char === ']');
      if (!validPair) {
        stack.length = 0;
        start = -1;
        continue;
      }

      if (stack.length === 0 && start >= 0) {
        pushCandidate(balancedSource.slice(start, i + 1));
        start = -1;
      }
    }
  }

  let best = null;
  for (let index = 0; index < candidateTexts.length; index += 1) {
    const candidate = candidateTexts[index];
    try {
      const parsed = JSON.parse(candidate);
      const score = scoreJsonCandidatePayload(parsed);
      if (!best || score > best.score || (score === best.score && index > best.index)) {
        best = { parsed, score, index };
      }
    } catch {
      // Try next candidate.
    }
  }

  if (best?.parsed !== undefined) {
    return best.parsed;
  }

  throw new Error('Nao foi possivel extrair JSON valido da resposta da IA.');
}

function tryExtractJsonPayload(rawText) {
  try {
    return { parsed: extractJsonPayload(rawText), error: null };
  } catch (error) {
    return { parsed: null, error };
  }
}

function buildRawPreview(rawText, maxLength = 320) {
  return normalizeString(rawText, '').replace(/\s+/g, ' ').slice(0, maxLength);
}

async function callOllamaVision(base64Image, requestId, systemPrompt, options = {}) {
  const forceJsonFormat = normalizeBool(options.forceJsonFormat, false);
  const ollamaPayload = {
    model: MODEL_NAME,
    messages: [
      {
        role: 'user',
        content: systemPrompt,
        images: [base64Image],
      },
    ],
    stream: STREAM_ENABLED,
    options: {
      temperature: 0.0,
      top_p: 0.1,
      repeat_penalty: 1.05,
    },
  };

  if (forceJsonFormat || !ENABLE_REASONING_THEN_JSON) {
    ollamaPayload.format = 'json';
  }

  const response = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(ollamaPayload),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Erro na IA: ${response.status} - ${errText}`);
  }

  if (!STREAM_ENABLED) {
    const payload = await response.json();
    return payload?.message?.content || '';
  }

  if (!response.body) {
    throw new Error('Resposta da IA sem corpo de stream.');
  }

  let accumulatedContent = '';
  let streamBuffer = '';

  for await (const rawChunk of response.body) {
    streamBuffer += rawChunk.toString('utf8');
    const lines = streamBuffer.split('\n');
    streamBuffer = lines.pop() || '';

    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (!line) {
        continue;
      }

      let frame;
      try {
        frame = JSON.parse(line);
      } catch {
        continue;
      }

      const token = frame?.message?.content || '';
      if (token) {
        accumulatedContent += token;
      }
    }
  }

  if (streamBuffer.trim()) {
    try {
      const frame = JSON.parse(streamBuffer.trim());
      const token = frame?.message?.content || '';
      if (token) {
        accumulatedContent += token;
      }
    } catch {
      // Ignora frame final incompleto para evitar abortar a passada.
    }
  }

  return accumulatedContent;
}

async function buildPlanFromBlueprint(file, options = {}) {
  const rejectInvalid = options.rejectInvalid ?? REJECT_INVALID_PLAN;
  const allowRecovery = options.allowRecovery ?? ENABLE_RECOVERY_PASS;
  const requestId = `req_${Date.now()}_${Math.random().toString(16).slice(2, 8)}`;

  logStructured('analyze_start', {
    requestId,
    filename: file.originalname || null,
    mimeType: file.mimetype,
    bytes: file.size,
    model: MODEL_NAME,
    ensembleSize: ANALYSIS_ENSEMBLE_SIZE,
  });

  const base64Image = file.buffer.toString('base64');
  let seedEntityLedger = [];

  try {
    const ledgerRaw = await callOllamaVision(base64Image, `${requestId}_ledger`, buildLedgerExtractionPrompt());
    const ledgerAttempt = tryExtractJsonPayload(ledgerRaw);

    if (ledgerAttempt.parsed) {
      seedEntityLedger = normalizeEntityLedger(ledgerAttempt.parsed);
      logStructured('ledger_extraction_completed', {
        requestId,
        entities: seedEntityLedger.length,
        measurable_entities: seedEntityLedger.filter((entity) => isMeasurableLedgerEntity(entity)).length,
      });
    } else {
      logStructured('ledger_extraction_failed', {
        requestId,
        reason: normalizeString(ledgerAttempt.error?.message, 'json_parse_failed'),
      });
    }
  } catch (error) {
    logStructured('ledger_extraction_error', {
      requestId,
      reason: normalizeString(error?.message, 'ledger_call_failed'),
    });
  }

  const measurableSeedCount = seedEntityLedger.filter((entity) => isMeasurableLedgerEntity(entity)).length;
  if (measurableSeedCount < LEDGER_RECALL_MIN_ENTITIES) {
    try {
      const recallRaw = await callOllamaVision(
        base64Image,
        `${requestId}_ledger_recall`,
        buildLedgerRecallPrompt(seedEntityLedger),
      );
      const recallAttempt = tryExtractJsonPayload(recallRaw);

      if (recallAttempt.parsed) {
        const recallLedger = normalizeEntityLedger(recallAttempt.parsed);
        const previousCount = seedEntityLedger.length;
        seedEntityLedger = normalizeEntityLedger([...seedEntityLedger, ...recallLedger]);
        logStructured('ledger_recall_completed', {
          requestId,
          previous_entities: previousCount,
          recall_entities: recallLedger.length,
          merged_entities: seedEntityLedger.length,
          measurable_entities: seedEntityLedger.filter((entity) => isMeasurableLedgerEntity(entity)).length,
        });
      } else {
        logStructured('ledger_recall_failed', {
          requestId,
          reason: normalizeString(recallAttempt.error?.message, 'json_parse_failed'),
        });
      }
    } catch (error) {
      logStructured('ledger_recall_error', {
        requestId,
        reason: normalizeString(error?.message, 'ledger_recall_call_failed'),
      });
    }
  }

  const missingEnvelopeClasses = getMissingEnvelopeRecallClasses(seedEntityLedger);
  if (missingEnvelopeClasses.length > 0) {
    try {
      let targetedRecallRaw = await callOllamaVision(
        base64Image,
        `${requestId}_ledger_recall_missing_${missingEnvelopeClasses.join('_')}`,
        buildMissingClassRecallPrompt(seedEntityLedger, missingEnvelopeClasses),
      );
      let targetedRecallAttempt = tryExtractJsonPayload(targetedRecallRaw);
      let usedStrictRetry = false;
      let strictRetryRaw = '';

      let mergedAfterFirstAttempt = seedEntityLedger;
      if (targetedRecallAttempt.parsed) {
        const firstLedger = normalizeEntityLedger(targetedRecallAttempt.parsed);
        mergedAfterFirstAttempt = normalizeEntityLedger([...seedEntityLedger, ...firstLedger]);
      }

      const stillMissingAfterFirstAttempt = missingEnvelopeClasses.filter(
        (className) => !hasMeasurableClassInLedger(mergedAfterFirstAttempt, className),
      );

      if (!targetedRecallAttempt.parsed || stillMissingAfterFirstAttempt.length > 0) {
        const retryReason = !targetedRecallAttempt.parsed
          ? 'parse_failed'
          : 'missing_class_not_recovered';
        try {
          strictRetryRaw = await callOllamaVision(
            base64Image,
            `${requestId}_ledger_recall_missing_${missingEnvelopeClasses.join('_')}_strict`,
            buildMissingClassRecallPrompt(seedEntityLedger, missingEnvelopeClasses, { forceJsonOnly: true }),
            { forceJsonFormat: true },
          );
          const strictRetryAttempt = tryExtractJsonPayload(strictRetryRaw);
          if (strictRetryAttempt.parsed) {
            usedStrictRetry = true;
            targetedRecallRaw = strictRetryRaw;
            targetedRecallAttempt = strictRetryAttempt;
            logStructured('ledger_targeted_recall_retry_succeeded', {
              requestId,
              missing_classes: missingEnvelopeClasses,
              retry_reason: retryReason,
            });
          }
        } catch (strictRetryError) {
          logStructured('ledger_targeted_recall_retry_error', {
            requestId,
            missing_classes: missingEnvelopeClasses,
            reason: normalizeString(strictRetryError?.message, 'strict_retry_call_failed'),
          });
        }
      }

      if (targetedRecallAttempt.parsed) {
        const targetedRecallLedger = normalizeEntityLedger(targetedRecallAttempt.parsed);
        const previousCount = seedEntityLedger.length;
        seedEntityLedger = normalizeEntityLedger([...seedEntityLedger, ...targetedRecallLedger]);
        logStructured('ledger_targeted_recall_completed', {
          requestId,
          missing_classes: missingEnvelopeClasses,
          previous_entities: previousCount,
          recall_entities: targetedRecallLedger.length,
          merged_entities: seedEntityLedger.length,
          strict_retry_used: usedStrictRetry,
          measurable_entities: seedEntityLedger.filter((entity) => isMeasurableLedgerEntity(entity)).length,
        });
      } else {
        logStructured('ledger_targeted_recall_failed', {
          requestId,
          missing_classes: missingEnvelopeClasses,
          reason: normalizeString(targetedRecallAttempt.error?.message, 'json_parse_failed'),
          raw_preview: buildRawPreview(targetedRecallRaw),
          strict_retry_raw_preview: strictRetryRaw ? buildRawPreview(strictRetryRaw) : '',
        });
      }
    } catch (error) {
      logStructured('ledger_targeted_recall_error', {
        requestId,
        missing_classes: missingEnvelopeClasses,
        reason: normalizeString(error?.message, 'ledger_targeted_recall_call_failed'),
      });
    }
  }

  const prompts = Array.from({ length: ANALYSIS_ENSEMBLE_SIZE }, (_, i) => buildSpecializedPrompt(i, seedEntityLedger));

  const rawResponses = [];
  const passExecutions = await Promise.allSettled(
    prompts.map((prompt, index) => callOllamaVision(base64Image, `${requestId}_pass${index + 1}`, prompt)),
  );

  for (let index = 0; index < passExecutions.length; index += 1) {
    const execution = passExecutions[index];
    if (execution.status === 'fulfilled') {
      rawResponses.push({ pass: index + 1, raw: execution.value });
      continue;
    }

    logStructured('analysis_pass_transport_failed', {
      requestId,
      pass: index + 1,
      reason: normalizeString(execution.reason?.message, 'ollama_call_failed'),
    });
  }

  const parsedPlans = [];
  for (let index = 0; index < rawResponses.length; index += 1) {
    const passData = rawResponses[index];
    let raw = passData.raw;
    let attempt = tryExtractJsonPayload(raw);
    let strictRetryRaw = '';
    let strictRetryUsed = false;

    if (!attempt.parsed) {
      try {
        strictRetryRaw = await callOllamaVision(
          base64Image,
          `${requestId}_pass${passData.pass}_strict`,
          buildSpecializedPrompt(passData.pass - 1, seedEntityLedger, { forceJsonOnly: true }),
          { forceJsonFormat: true },
        );
        const strictAttempt = tryExtractJsonPayload(strictRetryRaw);
        if (strictAttempt.parsed) {
          raw = strictRetryRaw;
          attempt = strictAttempt;
          strictRetryUsed = true;
          logStructured('analysis_pass_retry_succeeded', {
            requestId,
            pass: passData.pass,
          });
        }
      } catch (strictRetryError) {
        logStructured('analysis_pass_retry_error', {
          requestId,
          pass: passData.pass,
          reason: normalizeString(strictRetryError?.message, 'strict_retry_call_failed'),
        });
      }
    }

    if (!attempt.parsed) {
      logStructured('analysis_pass_failed', {
        requestId,
        pass: passData.pass,
        reason: normalizeString(attempt.error?.message, 'json_parse_failed'),
        raw_preview: buildRawPreview(passData.raw, 280),
        strict_retry_raw_preview: strictRetryRaw ? buildRawPreview(strictRetryRaw, 280) : '',
      });
      continue;
    }

    const normalized = normalizePlan(attempt.parsed, {
      entityLedgerSeed: seedEntityLedger,
    });
    logStructured('analysis_pass_completed', {
      requestId,
      pass: passData.pass,
      steps: normalized.steps.length,
      entities: (normalized.entity_ledger || []).length,
      strict_retry_used: strictRetryUsed,
      hasFolds: normalized.geometry_check.has_physical_bends_or_folds,
      hasHoles: normalized.geometry_check.has_circular_holes,
    });
    parsedPlans.push(normalized);
  }

  if (!parsedPlans.length) {
    if (seedEntityLedger.length > 0) {
      const fallbackPlan = buildFallbackPlanFromLedger(seedEntityLedger);
      logStructured('analysis_fallback_from_ledger', {
        requestId,
        entities: seedEntityLedger.length,
        synthesized_steps: fallbackPlan.steps.length,
      });

      if (!fallbackPlan.steps.length) {
        throw new Error(
          'Nenhuma passada da IA retornou JSON valido e o entity_ledger nao gerou etapas mensuraveis.',
        );
      }

      parsedPlans.push(fallbackPlan);
    } else {
      throw new Error('Nenhuma passada da IA retornou JSON valido para o plano de inspecao.');
    }
  }

  let ensemblePlans = [...parsedPlans];
  let { mergedPlan, diagnostics } = mergePlanEnsemble(ensemblePlans);
  let quality = scorePlanQuality(mergedPlan, diagnostics.agreement_ratio);
  let coverage = quality.coverage || analyzeClassCoverage(mergedPlan);

  const shouldRunRecovery =
    allowRecovery &&
    (mergedPlan.steps.length < 4 || quality.status !== 'high' || coverage.missing_required_classes.length > 0);
  if (shouldRunRecovery) {
    const recoveryRaw = await callOllamaVision(
      base64Image,
      `${requestId}_recovery`,
      buildRecoveryPrompt(mergedPlan, coverage, seedEntityLedger),
    );
    const recoveryAttempt = tryExtractJsonPayload(recoveryRaw);

    if (recoveryAttempt.parsed) {
      const recoveryPlan = normalizePlan(recoveryAttempt.parsed, {
        entityLedgerSeed: seedEntityLedger,
      });

      logStructured('analysis_recovery_completed', {
        requestId,
        steps: recoveryPlan.steps.length,
        entities: (recoveryPlan.entity_ledger || []).length,
        hasFolds: recoveryPlan.geometry_check.has_physical_bends_or_folds,
        hasHoles: recoveryPlan.geometry_check.has_circular_holes,
      });

      ensemblePlans = [...ensemblePlans, recoveryPlan];
      const remerged = mergePlanEnsemble(ensemblePlans);
      mergedPlan = remerged.mergedPlan;
      diagnostics = remerged.diagnostics;
      quality = scorePlanQuality(mergedPlan, diagnostics.agreement_ratio);
      coverage = quality.coverage || analyzeClassCoverage(mergedPlan);
    } else {
      logStructured('analysis_recovery_failed', {
        requestId,
        reason: normalizeString(recoveryAttempt.error?.message, 'json_parse_failed'),
      });
    }
  }

  if ((!Array.isArray(mergedPlan.entity_ledger) || mergedPlan.entity_ledger.length === 0) && seedEntityLedger.length > 0) {
    mergedPlan.entity_ledger = seedEntityLedger;
  }
  mergedPlan.steps = augmentStepsWithEntityLedger(mergedPlan.steps || [], mergedPlan.entity_ledger || []);
  diagnostics.selected_steps = (mergedPlan.steps || []).length;

  quality = scorePlanQuality(mergedPlan, diagnostics.agreement_ratio);
  coverage = quality.coverage || analyzeClassCoverage(mergedPlan);

  if (rejectInvalid && quality.must_reject) {
    throw new PlanRejectedError('Plano rejeitado por inconsistencias de interpretacao.', {
      plan: mergedPlan,
      quality,
      diagnostics,
      coverage,
    });
  }

  const capturePlan = summarizeCapturePlan(mergedPlan);

  logStructured('plan_ready', {
    requestId,
    partName: mergedPlan.part_name,
    steps: mergedPlan.steps.length,
    entities: (mergedPlan.entity_ledger || []).length,
    confidence: quality.confidence,
    qualityStatus: quality.status,
    agreement: diagnostics.agreement_ratio,
    missingRequiredClasses: coverage.missing_required_classes,
  });

  return {
    requestId,
    plan: mergedPlan,
    capturePlan,
    quality,
    diagnostics,
    coverage,
  };
}

function buildTechnicalReference(plan, coverage = null) {
  const effectiveCoverage = coverage || analyzeClassCoverage(plan);
  const ledgerSummary = summarizeEntityLedger(plan.entity_ledger || []);
  const thicknessSteps = (plan.steps || []).filter(
    (step) => resolveStepClass(step, parseCalloutValue(step?.source_callout)) === 'thickness',
  );
  const thicknessValues = thicknessSteps
    .map((step) => normalizeNumber(step.expected_value, 0))
    .filter((value) => isPlausibleThicknessValue(value));

  const inferredThickness = thicknessValues.length > 0 ? median(thicknessValues, thicknessValues[0]) : 0;
  const closestThicknessReference = findClosestStandardThickness(inferredThickness);

  return {
    source_document: MANUAL_TECHNICAL_REFERENCE.source_document,
    note_reference_image: '2026-04-17-Nota-21-10.png',
    revision: MANUAL_TECHNICAL_REFERENCE.revision,
    standards: MANUAL_TECHNICAL_REFERENCE.standards,
    profile_families: MANUAL_TECHNICAL_REFERENCE.profile_families,
    folded_profile_reference: {
      standard_thickness_mm: MANUAL_TECHNICAL_REFERENCE.standard_thickness_mm,
      typical_lengths_mm: MANUAL_TECHNICAL_REFERENCE.typical_lengths_mm,
    },
    visual_class_legend: NOTE_VISUAL_LEGEND,
    inferred: {
      detected_classes: effectiveCoverage.covered_focus_classes,
      required_classes: effectiveCoverage.required_classes,
      closest_standard_thickness: closestThicknessReference,
      ledger_summary: ledgerSummary,
    },
  };
}

function summarizeInspectionProfile(plan, coverage, capturePlan) {
  const classCounters = coverage?.by_class || analyzeClassCoverage(plan).by_class;
  const hiddenFeatureClasses = ['bend', 'hole', 'u_cutout'].filter((item) => (classCounters[item] || 0) > 0);

  return {
    total_steps: (plan.steps || []).length,
    class_counters: classCounters,
    hidden_feature_classes: hiddenFeatureClasses,
    recommended_capture_sequence: (capturePlan?.required_photos || []).map((photo) => photo.photo_id),
    review_priority: hiddenFeatureClasses.length > 0 ? 'hidden_features_first' : 'standard_linear_checks',
  };
}

function formatInterpretationResponse(inspectionId, plan, capturePlan, quality, diagnostics, coverage) {
  const effectiveCoverage = coverage || analyzeClassCoverage(plan);
  const technicalReference = buildTechnicalReference(plan, effectiveCoverage);
  const inspectionProfile = summarizeInspectionProfile(plan, effectiveCoverage, capturePlan);
  const evidenceSummary = summarizeEntityLedger(plan.entity_ledger || []);

  return {
    inspection_id: inspectionId,
    generated_at: nowIso(),
    part_name: plan.part_name,
    unit: plan.unit,
    notes: plan.notes,
    geometry_check: plan.geometry_check,
    entity_ledger: plan.entity_ledger || [],
    evidence_summary: evidenceSummary,
    steps: plan.steps,
    capture_plan: capturePlan,
    analysis_quality: quality,
    analysis_diagnostics: diagnostics,
    analysis_coverage: effectiveCoverage,
    technical_reference: technicalReference,
    inspection_profile: inspectionProfile,
  };
}

function buildValidationSummary(plan, measurements = []) {
  const measurementByStep = new Map();

  for (const item of measurements) {
    const stepId = normalizeString(item?.step_id || item?.id || '');
    if (stepId) {
      measurementByStep.set(stepId, item);
    }
  }

  const results = plan.steps.map((step) => {
    const measured = measurementByStep.get(step.id);

    if (!measured) {
      return {
        step_id: step.id,
        title: step.title,
        status: 'missing',
        expected_value: step.expected_value,
        tolerance: step.tolerance,
        unit: step.unit,
        message: 'Sem medicao enviada para esta etapa.',
      };
    }

    const measuredValue = normalizeNumber(measured.measured_value, NaN);
    if (!Number.isFinite(measuredValue)) {
      return {
        step_id: step.id,
        title: step.title,
        status: 'invalid',
        expected_value: step.expected_value,
        tolerance: step.tolerance,
        unit: step.unit,
        measured_value: measured.measured_value,
        message: 'Valor medido invalido.',
      };
    }

    const deviation = measuredValue - step.expected_value;
    const absDeviation = Math.abs(deviation);
    const pass = absDeviation <= step.tolerance;

    return {
      step_id: step.id,
      title: step.title,
      status: pass ? 'approved' : 'rejected',
      expected_value: step.expected_value,
      measured_value: measuredValue,
      deviation,
      tolerance: step.tolerance,
      unit: step.unit,
      message: pass ? 'Dentro da tolerancia.' : 'Fora da tolerancia.',
    };
  });

  const approved = results.filter((r) => r.status === 'approved').length;
  const rejected = results.filter((r) => r.status === 'rejected').length;
  const missing = results.filter((r) => r.status === 'missing').length;
  const invalid = results.filter((r) => r.status === 'invalid').length;

  return {
    overall_status: rejected === 0 && missing === 0 && invalid === 0 ? 'approved' : 'needs_review',
    approved,
    rejected,
    missing,
    invalid,
    total_steps: plan.steps.length,
    step_results: results,
  };
}

app.get('/health', (_req, res) => {
  res.status(200).json({
    ok: true,
    service: 'sidera_backend',
    timestamp: nowIso(),
    model: MODEL_NAME,
    ensemble_size: ANALYSIS_ENSEMBLE_SIZE,
    recovery_enabled: ENABLE_RECOVERY_PASS,
    model_first_strict_mode: MODEL_FIRST_STRICT_MODE,
    reject_invalid_plan: REJECT_INVALID_PLAN,
    strict_min_confidence: STRICT_MIN_CONFIDENCE,
    ledger_strict_mapping: LEDGER_STRICT_MAPPING,
    min_ledger_entity_confidence: MIN_LEDGER_ENTITY_CONFIDENCE,
    ledger_max_entities: LEDGER_MAX_ENTITIES,
  });
});

app.get('/api/v1/reference/manual', (_req, res) => {
  return res.status(200).json({
    generated_at: nowIso(),
    technical_reference: {
      ...MANUAL_TECHNICAL_REFERENCE,
      visual_class_legend: NOTE_VISUAL_LEGEND,
    },
  });
});

app.post('/api/analyze', upload.single('blueprint'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Nenhuma imagem enviada.' });
  }

  const strict = String(req.query.strict || 'false').toLowerCase() === 'true';
  const allowRecovery = String(req.query.recovery || String(ENABLE_RECOVERY_PASS)).toLowerCase() !== 'false';

  try {
    cleanupInspectionStore();
    const inspectionId = generateInspectionId();
    const { plan, capturePlan, quality, diagnostics, coverage } = await buildPlanFromBlueprint(req.file, {
      rejectInvalid: strict && REJECT_INVALID_PLAN,
      allowRecovery,
    });

    INSPECTIONS.set(inspectionId, {
      createdAt: nowIso(),
      plan,
      capturePlan,
      quality,
      diagnostics,
      coverage,
    });

    const payload = formatInterpretationResponse(inspectionId, plan, capturePlan, quality, diagnostics, coverage);

    if (strict && quality.confidence < STRICT_MIN_CONFIDENCE) {
      return res.status(422).json({
        error: 'Plano com baixa confianca para modo estrito.',
        inspection_id: inspectionId,
        analysis_quality: quality,
        analysis_diagnostics: diagnostics,
      });
    }

    return res.status(200).json(payload);
  } catch (error) {
    if (error instanceof PlanRejectedError) {
      return res.status(error.statusCode || 422).json({
        error: error.message,
        details: error.details,
      });
    }
    console.error('Falha no backend:', error);
    return res.status(500).json({ error: 'Falha ao processar o desenho', details: error.message });
  }
});

app.post('/api/v1/blueprints/interpret', upload.single('blueprint'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Nenhuma imagem enviada no campo blueprint.' });
  }

  const strict = String(req.query.strict || 'true').toLowerCase() !== 'false';
  const allowRecovery = String(req.query.recovery || String(ENABLE_RECOVERY_PASS)).toLowerCase() !== 'false';

  try {
    cleanupInspectionStore();
    const inspectionId = generateInspectionId();
    const { plan, capturePlan, quality, diagnostics, coverage } = await buildPlanFromBlueprint(req.file, {
      rejectInvalid: strict && REJECT_INVALID_PLAN,
      allowRecovery,
    });

    INSPECTIONS.set(inspectionId, {
      createdAt: nowIso(),
      plan,
      capturePlan,
      quality,
      diagnostics,
      coverage,
    });

    if (strict && quality.confidence < STRICT_MIN_CONFIDENCE) {
      return res.status(422).json({
        error: 'Plano com baixa confianca para modo estrito.',
        inspection_id: inspectionId,
        analysis_quality: quality,
        analysis_diagnostics: diagnostics,
      });
    }

    return res
      .status(200)
      .json(formatInterpretationResponse(inspectionId, plan, capturePlan, quality, diagnostics, coverage));
  } catch (error) {
    if (error instanceof PlanRejectedError) {
      return res.status(error.statusCode || 422).json({
        error: error.message,
        details: error.details,
      });
    }
    console.error('Falha ao interpretar desenho:', error);
    return res.status(500).json({
      error: 'Falha ao interpretar desenho tecnico.',
      details: error.message,
    });
  }
});

app.post('/api/v1/inspections/validate', (req, res) => {
  try {
    cleanupInspectionStore();
    const inspectionId = normalizeString(req.body?.inspection_id, '');
    const providedPlan = req.body?.plan;
    const measurements = Array.isArray(req.body?.measurements) ? req.body.measurements : [];

    let plan = null;

    if (inspectionId) {
      const stored = INSPECTIONS.get(inspectionId);
      if (!stored) {
        return res.status(404).json({ error: 'inspection_id nao encontrado ou expirado.' });
      }
      plan = stored.plan;
    } else if (providedPlan) {
      plan = normalizePlan(providedPlan);
    } else {
      return res.status(400).json({
        error: 'Envie inspection_id ou plan para validar.',
      });
    }

    const summary = buildValidationSummary(plan, measurements);

    return res.status(200).json({
      inspection_id: inspectionId || null,
      validated_at: nowIso(),
      part_name: plan.part_name,
      overall_status: summary.overall_status,
      approved_steps: summary.approved,
      rejected_steps: summary.rejected,
      missing_steps: summary.missing,
      invalid_steps: summary.invalid,
      total_steps: summary.total_steps,
      step_results: summary.step_results,
    });
  } catch (error) {
    console.error('Falha ao validar inspecao:', error);
    return res.status(500).json({
      error: 'Falha ao validar inspecao.',
      details: error.message,
    });
  }
});

app.get('/api/v1/inspections/:inspectionId', (req, res) => {
  cleanupInspectionStore();
  const inspectionId = normalizeString(req.params.inspectionId, '');
  const entry = INSPECTIONS.get(inspectionId);

  if (!entry) {
    return res.status(404).json({ error: 'inspection_id nao encontrado ou expirado.' });
  }

  return res.status(200).json(
    formatInterpretationResponse(
      inspectionId,
      entry.plan,
      entry.capturePlan,
      entry.quality || scorePlanQuality(entry.plan, 1),
      entry.diagnostics || { ensemble_size: 1, selected_steps: entry.plan.steps.length, agreement_ratio: 1 },
      entry.coverage || analyzeClassCoverage(entry.plan),
    ),
  );
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Cerebro Sidera (Node + Qwen) rodando na porta ${PORT}`);
});
