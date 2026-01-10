// DecisionAgent Rule Builder - Main Application

// Helper function to get the base path for API calls
// This handles both standalone and Rails-mounted scenarios
function getBasePath() {
    // Try to get from <base> tag first
    const baseTag = document.querySelector('base');
    if (baseTag && baseTag.href) {
        try {
            // Parse the base URL
            const baseUrl = new URL(baseTag.href, window.location.href);
            let path = baseUrl.pathname;
            
            // Ensure it ends with / for proper path joining
            if (path && !path.endsWith('/')) {
                path += '/';
            }
            
            return path;
        } catch (e) {
            // If URL parsing fails, try simple string matching
            // Check if it's an absolute path
            if (baseTag.href.startsWith('/')) {
                // Extract path from absolute URL
                const match = baseTag.href.match(/^(https?:\/\/[^\/]+)?(\/.*?)\/?$/);
                if (match && match[2]) {
                    return match[2].endsWith('/') ? match[2] : match[2] + '/';
                }
            } else if (baseTag.href.startsWith('./')) {
                // Relative path - use current location's directory
                const pathname = window.location.pathname;
                // Get directory path (remove filename if present)
                const dirPath = pathname.substring(0, pathname.lastIndexOf('/') + 1);
                return dirPath;
            }
        }
    }
    
    // Fallback: detect from current location
    // If we're at /decision_agent, use that as base
    const pathname = window.location.pathname;
    if (pathname.includes('/decision_agent')) {
        const match = pathname.match(/^(\/.*?\/decision_agent)\/?/);
        if (match) {
            return match[1].endsWith('/') ? match[1] : match[1] + '/';
        }
    }
    
    // Default: use current directory
    const dirPath = pathname.substring(0, pathname.lastIndexOf('/') + 1);
    return dirPath || '/';
}

class RuleBuilder {
    constructor() {
        this.rules = [];
        this.currentRule = null;
        this.currentRuleIndex = null;
        this.currentCondition = null;
        this.basePath = getBasePath();
        this.init();
    }

    init() {
        this.bindEvents();
        this.updateJSONPreview();
    }

    getAuthHeaders() {
        const token = localStorage.getItem('auth_token');
        const headers = { 'Content-Type': 'application/json' };
        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }
        return headers;
    }

    bindEvents() {
        // Rule management
        document.getElementById('addRuleBtn').addEventListener('click', () => this.openRuleModal());
        document.getElementById('saveRuleBtn').addEventListener('click', () => this.saveRule());
        document.getElementById('closeModalBtn').addEventListener('click', () => this.closeModal());
        document.getElementById('cancelModalBtn').addEventListener('click', () => this.closeModal());

        // Actions
        document.getElementById('validateBtn').addEventListener('click', () => this.validateRules());
        document.getElementById('testRuleBtn').addEventListener('click', () => this.openTestRuleModal());
        document.getElementById('clearBtn').addEventListener('click', () => this.clearAll());
        document.getElementById('loadExampleBtn').addEventListener('click', () => this.loadExample());

        // Export/Import
        document.getElementById('copyBtn').addEventListener('click', () => this.copyJSON());
        document.getElementById('downloadBtn').addEventListener('click', () => this.downloadJSON());
        document.getElementById('importFile').addEventListener('change', (e) => this.importJSON(e));

        // Versioning
        document.getElementById('saveVersionBtn').addEventListener('click', () => this.openSaveVersionModal());
        document.getElementById('refreshVersionsBtn').addEventListener('click', () => this.loadVersionHistory());
        document.getElementById('closeSaveVersionBtn').addEventListener('click', () => this.closeSaveVersionModal());
        document.getElementById('cancelSaveVersionBtn').addEventListener('click', () => this.closeSaveVersionModal());
        document.getElementById('confirmSaveVersionBtn').addEventListener('click', () => this.confirmSaveVersion());
        document.getElementById('closeCompareBtn').addEventListener('click', () => this.closeCompareModal());
        document.getElementById('closeCompareModalBtn').addEventListener('click', () => this.closeCompareModal());

        // Test Rule
        document.getElementById('runTestBtn').addEventListener('click', () => this.runTest());
        document.getElementById('closeTestRuleBtn').addEventListener('click', () => this.closeTestRuleModal());
        document.getElementById('closeTestRuleModalBtn').addEventListener('click', () => this.closeTestRuleModal());

        // Modal close on outside click
        document.getElementById('ruleModal').addEventListener('click', (e) => {
            if (e.target.id === 'ruleModal') {
                this.closeModal();
            }
        });

        document.getElementById('saveVersionModal').addEventListener('click', (e) => {
            if (e.target.id === 'saveVersionModal') {
                this.closeSaveVersionModal();
            }
        });

        document.getElementById('compareVersionsModal').addEventListener('click', (e) => {
            if (e.target.id === 'compareVersionsModal') {
                this.closeCompareModal();
            }
        });

        // Operator change - hide/show value input
        document.addEventListener('change', (e) => {
            if (e.target.classList.contains('operator-select')) {
                this.handleOperatorChange(e.target);
            }
        });
    }

    openRuleModal(index = null) {
        this.currentRuleIndex = index;
        const modal = document.getElementById('ruleModal');
        const modalTitle = document.getElementById('modalTitle');

        if (index !== null) {
            // Edit existing rule
            this.currentRule = { ...this.rules[index] };
            modalTitle.textContent = `Edit Rule: ${this.currentRule.id}`;
            this.populateRuleModal(this.currentRule);
        } else {
            // New rule
            this.currentRule = {
                id: '',
                if: { field: '', op: 'eq', value: '' },
                then: { decision: '', weight: 0.8, reason: '' }
            };
            modalTitle.textContent = 'Create New Rule';
            this.populateRuleModal(this.currentRule);
        }

        modal.classList.remove('hidden');
    }

    populateRuleModal(rule) {
        document.getElementById('ruleId').value = rule.id || '';
        document.getElementById('thenDecision').value = rule.then?.decision || '';
        document.getElementById('thenWeight').value = rule.then?.weight || 0.8;
        document.getElementById('thenReason').value = rule.then?.reason || '';

        // Build condition UI
        const conditionBuilder = document.getElementById('conditionBuilder');
        conditionBuilder.innerHTML = '';

        if (!rule.if) {
            this.addFieldCondition(conditionBuilder);
        } else {
            this.buildConditionUI(rule.if, conditionBuilder);
        }
    }

    buildConditionUI(condition, container) {
        if (condition.field !== undefined) {
            // Field condition
            const conditionEl = this.createFieldCondition(condition);
            container.appendChild(conditionEl);
        } else if (condition.all !== undefined) {
            // All (AND) condition
            const compositeEl = this.createCompositeCondition('all', condition.all);
            container.appendChild(compositeEl);
        } else if (condition.any !== undefined) {
            // Any (OR) condition
            const compositeEl = this.createCompositeCondition('any', condition.any);
            container.appendChild(compositeEl);
        } else {
            // Fallback
            this.addFieldCondition(container);
        }
    }

    createFieldCondition(data = {}) {
        const template = document.getElementById('fieldConditionTemplate');
        const clone = template.content.cloneNode(true);
        const conditionItem = clone.querySelector('.condition-item');

        // Populate data
        if (data.field) conditionItem.querySelector('.field-path').value = data.field;
        if (data.op) conditionItem.querySelector('.operator-select').value = data.op;
        if (data.value !== undefined) conditionItem.querySelector('.field-value').value = data.value;

        // Handle operator-specific visibility
        const operatorSelect = conditionItem.querySelector('.operator-select');
        this.handleOperatorChange(operatorSelect);

        // Remove button
        conditionItem.querySelector('.btn-remove').addEventListener('click', (e) => {
            conditionItem.remove();
        });

        // Type change
        conditionItem.querySelector('.condition-type-select').addEventListener('change', (e) => {
            this.convertConditionType(conditionItem, e.target.value);
        });

        return conditionItem;
    }

    createCompositeCondition(type = 'all', subconditions = []) {
        const template = document.getElementById('compositeConditionTemplate');
        const clone = template.content.cloneNode(true);
        const conditionItem = clone.querySelector('.condition-item');
        const typeSelect = conditionItem.querySelector('.condition-type-select');
        const subContainer = conditionItem.querySelector('.subconditions-container');

        // Set type
        typeSelect.value = type;

        // Add subconditions
        if (subconditions.length === 0) {
            // Add one empty field condition
            subContainer.appendChild(this.createFieldCondition());
        } else {
            subconditions.forEach(subcond => {
                this.buildConditionUI(subcond, subContainer);
            });
        }

        // Add subcondition button
        conditionItem.querySelector('.btn-add-subcondition').addEventListener('click', () => {
            subContainer.appendChild(this.createFieldCondition());
        });

        // Remove button
        conditionItem.querySelector('.btn-remove').addEventListener('click', () => {
            conditionItem.remove();
        });

        // Type change
        typeSelect.addEventListener('change', (e) => {
            this.convertConditionType(conditionItem, e.target.value);
        });

        return conditionItem;
    }

    convertConditionType(conditionItem, newType) {
        const parent = conditionItem.parentElement;
        if (!parent) return;

        if (newType === 'field') {
            // Convert to field condition
            const newCondition = this.createFieldCondition();
            parent.replaceChild(newCondition, conditionItem);
        } else {
            // Convert to composite (all/any)
            const newCondition = this.createCompositeCondition(newType);
            parent.replaceChild(newCondition, conditionItem);
        }
    }

    addFieldCondition(container) {
        const conditionEl = this.createFieldCondition();
        container.appendChild(conditionEl);
    }

    handleOperatorChange(selectElement) {
        const valueInput = selectElement.parentElement.querySelector('.field-value');
        const operator = selectElement.value;

        // Operators that don't need a value
        if (operator === 'present' || operator === 'blank') {
            valueInput.style.display = 'none';
            valueInput.value = '';
            return;
        }

        valueInput.style.display = 'block';

        // Set helpful placeholders based on operator
        const placeholders = {
            // Basic operators
            'eq': 'value',
            'neq': 'value',
            'gt': '100',
            'gte': '100',
            'lt': '100',
            'lte': '100',
            'in': '["value1", "value2"]',

            // String operators
            'contains': 'substring',
            'starts_with': 'prefix',
            'ends_with': 'suffix',
            'matches': '^pattern.*$',

            // Numeric operators
            'between': '[min, max] or {"min": 0, "max": 100}',
            'modulo': '[divisor, remainder] or {"divisor": 2, "remainder": 0}',

            // Mathematical functions - Trigonometric
            'sin': 'expected result (e.g., 0.0 for sin(0))',
            'cos': 'expected result (e.g., 1.0 for cos(0))',
            'tan': 'expected result (e.g., 0.0 for tan(0))',
            'asin': 'expected result (e.g., 1.571 for asin(1))',
            'acos': 'expected result (e.g., 0.0 for acos(1))',
            'atan': 'expected result (e.g., 0.785 for atan(1))',
            'atan2': '{"y": 1, "result": 0.785} or [1, 0.785]',
            // Hyperbolic
            'sinh': 'expected result (e.g., 0.0 for sinh(0))',
            'cosh': 'expected result (e.g., 1.0 for cosh(0))',
            'tanh': 'expected result (e.g., 0.0 for tanh(0))',
            // Power and roots
            'sqrt': 'expected result (e.g., 3.0 for sqrt(9))',
            'cbrt': 'expected result (e.g., 2.0 for cbrt(8))',
            'power': '[exponent, result] or {"exponent": 2, "result": 4}',
            'exp': 'expected result (e.g., 2.718 for exp(1))',
            // Logarithmic
            'log': 'expected result (e.g., 0.0 for log(1))',
            'log10': 'expected result (e.g., 2.0 for log10(100))',
            'log2': 'expected result (e.g., 3.0 for log2(8))',
            // Rounding
            'round': 'expected rounded value (e.g., 3 for round(3.4))',
            'floor': 'expected floor value (e.g., 3 for floor(3.9))',
            'ceil': 'expected ceiling value (e.g., 4 for ceil(3.1))',
            'truncate': 'expected truncated value (e.g., 3 for truncate(3.9))',
            'abs': 'expected absolute value (e.g., 5 for abs(-5))',
            // Advanced math
            'factorial': 'expected result (e.g., 120 for factorial(5))',
            'gcd': '{"other": 12, "result": 6} or [12, 6]',
            'lcm': '{"other": 12, "result": 36} or [12, 36]',
            // Statistical (these are for arrays)
            'min': 'expected minimum value (e.g., 1 for min([3, 1, 5, 2]))',
            'max': 'expected maximum value (e.g., 5 for max([3, 1, 5, 2]))',

            // Statistical aggregations
            'sum': 'expected sum (e.g., 100) or {"min": 50, "max": 150}',
            'average': 'expected average (e.g., 25.5) or {"gt": 20, "lt": 30}',
            'mean': 'expected mean (e.g., 25.5) or {"gt": 20, "lt": 30}',
            'median': 'expected median (e.g., 25) or {"gt": 20}',
            'stddev': 'expected stddev (e.g., 5.2) or {"lt": 10}',
            'standard_deviation': 'expected stddev (e.g., 5.2) or {"lt": 10}',
            'variance': 'expected variance (e.g., 27.04) or {"lt": 100}',
            'percentile': '{"percentile": 95, "threshold": 200} or {"percentile": 95, "gt": 100}',
            'count': 'expected count (e.g., 10) or {"min": 5, "max": 20}',

            // Date/time operators
            'before_date': '2025-12-31',
            'after_date': '2024-01-01',
            'within_days': '7',
            'day_of_week': 'monday or 1',

            // Duration calculations
            'duration_seconds': '{"end": "now", "max": 3600} or {"end": "field.end_time", "min": 60}',
            'duration_minutes': '{"end": "now", "max": 60} or {"end": "field.end_time", "min": 5}',
            'duration_hours': '{"end": "now", "max": 24} or {"end": "field.end_time", "min": 1}',
            'duration_days': '{"end": "now", "max": 7} or {"end": "field.end_time", "min": 1}',

            // Date arithmetic
            'add_days': '{"days": 7, "compare": "lt", "target": "now"}',
            'subtract_days': '{"days": 1, "compare": "gt", "target": "now"}',
            'add_hours': '{"hours": 2, "compare": "lt", "target": "now"}',
            'subtract_hours': '{"hours": 1, "compare": "gt", "target": "now"}',
            'add_minutes': '{"minutes": 30, "compare": "lt", "target": "now"}',
            'subtract_minutes': '{"minutes": 15, "compare": "gt", "target": "now"}',

            // Time components
            'hour_of_day': '9 or {"min": 9, "max": 17}',
            'day_of_month': '15 or {"gte": 1, "lte": 31}',
            'month': '12 or {"gte": 1, "lte": 12}',
            'year': '2025 or {"gte": 2024}',
            'week_of_year': '25 or {"gte": 1, "lte": 52}',

            // Rate calculations
            'rate_per_second': '{"max": 10} or {"min": 5, "max": 100}',
            'rate_per_minute': '{"max": 600} or {"min": 50, "max": 1000}',
            'rate_per_hour': '{"max": 36000} or {"min": 5000, "max": 50000}',

            // Moving window
            'moving_average': '{"window": 5, "threshold": 100} or {"window": 5, "gt": 50}',
            'moving_sum': '{"window": 10, "threshold": 1000} or {"window": 10, "lt": 2000}',
            'moving_max': '{"window": 5, "threshold": 200} or {"window": 5, "gt": 100}',
            'moving_min': '{"window": 5, "threshold": 10} or {"window": 5, "lt": 50}',

            // Financial calculations
            'compound_interest': '{"rate": 0.05, "periods": 12, "result": 1050}',
            'present_value': '{"rate": 0.05, "periods": 10, "result": 613.91}',
            'future_value': '{"rate": 0.05, "periods": 10, "result": 1628.89}',
            'payment': '{"rate": 0.05, "periods": 12, "result": 100}',

            // String aggregations
            'join': '{"separator": ",", "result": "a,b,c"} or {"separator": ",", "contains": "a"}',
            'length': '{"max": 500} or {"min": 10, "max": 100}',

            // Collection operators
            'contains_all': '["item1", "item2"]',
            'contains_any': '["item1", "item2"]',
            'intersects': '["item1", "item2"]',
            'subset_of': '["valid1", "valid2", "valid3"]',

            // Geospatial operators
            'within_radius': '{"center": {"lat": 40.7128, "lon": -74.0060}, "radius": 10}',
            'in_polygon': '[{"lat": 40, "lon": -74}, {"lat": 41, "lon": -74}, ...]'
        };

        valueInput.placeholder = placeholders[operator] || 'value';

        // Add title attribute with helpful hint
        const hints = {
            'between': 'Range: [min, max] or {"min": 0, "max": 100}',
            'modulo': 'Modulo: [divisor, remainder] or {"divisor": 2, "remainder": 0}',
            'matches': 'Regular expression pattern (e.g., ^user@company\\.com$)',
            'within_days': 'Number of days from now (e.g., 7 for within a week)',
            'sum': 'Numeric or {"min": 50, "max": 150}',
            'average': 'Numeric or {"gt": 20, "lt": 30}',
            'mean': 'Numeric or {"gt": 20, "lt": 30}',
            'median': 'Numeric or {"gt": 20}',
            'stddev': 'Numeric or {"lt": 10}',
            'standard_deviation': 'Numeric or {"lt": 10}',
            'variance': 'Numeric or {"lt": 100}',
            'percentile': '{"percentile": 95, "threshold": 200}',
            'count': 'Numeric or {"min": 5, "max": 20}',
            'duration_seconds': '{"end": "now" or "field.path", "max": 3600}',
            'duration_minutes': '{"end": "now" or "field.path", "max": 60}',
            'duration_hours': '{"end": "now" or "field.path", "max": 24}',
            'duration_days': '{"end": "now" or "field.path", "max": 7}',
            'add_days': '{"days": 7, "compare": "lt", "target": "now" or "field.path"}',
            'subtract_days': '{"days": 1, "compare": "gt", "target": "now" or "field.path"}',
            'add_hours': '{"hours": 2, "compare": "lt", "target": "now" or "field.path"}',
            'subtract_hours': '{"hours": 1, "compare": "gt", "target": "now" or "field.path"}',
            'add_minutes': '{"minutes": 30, "compare": "lt", "target": "now" or "field.path"}',
            'subtract_minutes': '{"minutes": 15, "compare": "gt", "target": "now" or "field.path"}',
            'hour_of_day': 'Numeric (0-23) or {"min": 9, "max": 17}',
            'day_of_month': 'Numeric (1-31) or {"gte": 1, "lte": 31}',
            'month': 'Numeric (1-12) or {"gte": 1, "lte": 12}',
            'year': 'Numeric or {"gte": 2024}',
            'week_of_year': 'Numeric (1-52) or {"gte": 1, "lte": 52}',
            'rate_per_second': '{"max": 10} or {"min": 5, "max": 100}',
            'rate_per_minute': '{"max": 600} or {"min": 50, "max": 1000}',
            'rate_per_hour': '{"max": 36000} or {"min": 5000, "max": 50000}',
            'moving_average': '{"window": 5, "threshold": 100}',
            'moving_sum': '{"window": 10, "threshold": 1000}',
            'moving_max': '{"window": 5, "threshold": 200}',
            'moving_min': '{"window": 5, "threshold": 10}',
            'compound_interest': '{"rate": 0.05, "periods": 12, "result": 1050}',
            'present_value': '{"rate": 0.05, "periods": 10, "result": 613.91}',
            'future_value': '{"rate": 0.05, "periods": 10, "result": 1628.89}',
            'payment': '{"rate": 0.05, "periods": 12, "result": 100}',
            'join': '{"separator": ",", "result": "a,b,c"}',
            'length': '{"max": 500} or {"min": 10, "max": 100}',
            'day_of_week': 'Day name (monday) or number (0=Sunday, 1=Monday, ...)',
            'within_radius': 'JSON: {"center": {"lat": y, "lon": x}, "radius": km}',
            'in_polygon': 'Array of coordinates: [{"lat": y, "lon": x}, ...]',
            // Trigonometric functions
            'sin': 'Expected result of sin(field_value). Example: 0.0 for sin(0), 1.0 for sin(π/2)',
            'cos': 'Expected result of cos(field_value). Example: 1.0 for cos(0), 0.0 for cos(π/2)',
            'tan': 'Expected result of tan(field_value). Example: 0.0 for tan(0), 1.0 for tan(π/4)',
            'asin': 'Expected result of asin(field_value). Input must be [-1, 1]. Example: 1.571 for asin(1) = π/2',
            'acos': 'Expected result of acos(field_value). Input must be [-1, 1]. Example: 0.0 for acos(1)',
            'atan': 'Expected result of atan(field_value). Example: 0.785 for atan(1) = π/4',
            'atan2': 'atan2(field_value, y). Format: {"y": 1, "result": 0.785} or [1, 0.785]',
            // Hyperbolic functions
            'sinh': 'Expected result of sinh(field_value). Example: 0.0 for sinh(0), 1.175 for sinh(1)',
            'cosh': 'Expected result of cosh(field_value). Example: 1.0 for cosh(0), 1.543 for cosh(1)',
            'tanh': 'Expected result of tanh(field_value). Example: 0.0 for tanh(0), 0.762 for tanh(1)',
            // Power and roots
            'sqrt': 'Expected result of sqrt(field_value). Example: 3.0 for sqrt(9), 5.0 for sqrt(25)',
            'cbrt': 'Expected result of cbrt(field_value) = cube root. Example: 2.0 for cbrt(8), -2.0 for cbrt(-8)',
            'power': 'Power: Checks if field^exponent == result. Format: [exponent, result] or {"exponent": 2, "result": 4}. Example: [2, 4] means 2^2 == 4',
            'exp': 'Expected result of exp(field_value) = e^field_value. Example: 2.718 for exp(1), 7.389 for exp(2)',
            // Logarithmic functions
            'log': 'Expected result of log(field_value) = natural logarithm (base e). Example: 0.0 for log(1), 2.303 for log(10)',
            'log10': 'Expected result of log10(field_value) = base 10 logarithm. Example: 2.0 for log10(100), 3.0 for log10(1000)',
            'log2': 'Expected result of log2(field_value) = base 2 logarithm. Example: 3.0 for log2(8), 4.0 for log2(16)',
            // Rounding functions
            'round': 'Expected rounded value to nearest integer. Example: 3 for round(3.4), 4 for round(3.6)',
            'floor': 'Expected floor value (round down). Example: 3 for floor(3.9), -4 for floor(-3.1)',
            'ceil': 'Expected ceiling value (round up). Example: 4 for ceil(3.1), -3 for ceil(-3.9)',
            'truncate': 'Expected truncated value (remove decimal part). Example: 3 for truncate(3.9), -3 for truncate(-3.9)',
            'abs': 'Expected absolute value. Example: 5 for abs(-5) or abs(5), 3.14 for abs(-3.14)',
            // Advanced mathematical functions
            'factorial': 'Expected result of factorial(field_value). Input must be non-negative integer. Example: 120 for factorial(5), 720 for factorial(6)',
            'gcd': 'Greatest Common Divisor: gcd(field_value, other) == result. Format: {"other": 12, "result": 6} or [12, 6]. Example: gcd(18, 12) == 6',
            'lcm': 'Least Common Multiple: lcm(field_value, other) == result. Format: {"other": 12, "result": 36} or [12, 36]. Example: lcm(9, 12) == 36',
            // Statistical aggregations (for arrays)
            'min': 'Expected minimum value from array. Example: 1 for min([3, 1, 5, 2]), 0.5 for min([1.5, 2.0, 0.5])',
            'max': 'Expected maximum value from array. Example: 5 for max([3, 1, 5, 2]), 100.0 for max([10.5, 100.0, 50.0])'
        };

        if (hints[operator]) {
            valueInput.title = hints[operator];
        } else {
            valueInput.title = '';
        }
    }

    parseConditionUI(conditionElement) {
        const typeSelect = conditionElement.querySelector('.condition-type-select');
        const type = typeSelect.value;

        if (type === 'field') {
            // Field condition
            const field = conditionElement.querySelector('.field-path').value.trim();
            const op = conditionElement.querySelector('.operator-select').value;
            const value = conditionElement.querySelector('.field-value').value;

            const condition = { field, op };

            // Add value only if needed
            if (op !== 'present' && op !== 'blank') {
                // Try to parse as JSON for arrays/objects
                try {
                    condition.value = JSON.parse(value);
                } catch {
                    condition.value = value;
                }
            }

            return condition;
        } else {
            // Composite condition (all/any)
            const subContainer = conditionElement.querySelector('.subconditions-container');
            const subconditions = Array.from(subContainer.children).map(child =>
                this.parseConditionUI(child)
            );

            return { [type]: subconditions };
        }
    }

    saveRule() {
        // Validate inputs
        const ruleId = document.getElementById('ruleId').value.trim();
        const thenDecision = document.getElementById('thenDecision').value.trim();

        if (!ruleId) {
            alert('Rule ID is required');
            return;
        }

        if (!thenDecision) {
            alert('Decision is required');
            return;
        }

        // Parse condition
        const conditionBuilder = document.getElementById('conditionBuilder');
        const conditionElements = Array.from(conditionBuilder.children);

        if (conditionElements.length === 0) {
            alert('At least one condition is required');
            return;
        }

        const ifCondition = this.parseConditionUI(conditionElements[0]);

        // Build then clause
        const thenClause = {
            decision: thenDecision
        };

        const weight = parseFloat(document.getElementById('thenWeight').value);
        if (weight >= 0 && weight <= 1) {
            thenClause.weight = weight;
        }

        const reason = document.getElementById('thenReason').value.trim();
        if (reason) {
            thenClause.reason = reason;
        }

        // Create rule object
        const rule = {
            id: ruleId,
            if: ifCondition,
            then: thenClause
        };

        // Save or update
        if (this.currentRuleIndex !== null) {
            this.rules[this.currentRuleIndex] = rule;
        } else {
            this.rules.push(rule);
        }

        this.closeModal();
        this.renderRules();
        this.updateJSONPreview();
    }

    closeModal() {
        document.getElementById('ruleModal').classList.add('hidden');
        this.currentRule = null;
        this.currentRuleIndex = null;
    }

    renderRules() {
        const container = document.getElementById('rulesContainer');

        if (this.rules.length === 0) {
            container.innerHTML = '<p style="text-align: center; color: #6b7280; padding: 20px;">No rules yet. Click "Add Rule" to create one.</p>';
            return;
        }

        container.innerHTML = '';

        this.rules.forEach((rule, index) => {
            const ruleCard = document.createElement('div');
            ruleCard.className = 'rule-card';

            const conditionSummary = this.getConditionSummary(rule.if);

            ruleCard.innerHTML = `
                <div class="rule-header">
                    <span class="rule-id">${this.escapeHtml(rule.id)}</span>
                    <div class="rule-actions">
                        <button class="btn btn-sm btn-secondary edit-btn">Edit</button>
                        <button class="btn-remove delete-btn">×</button>
                    </div>
                </div>
                <div class="rule-summary">
                    IF: ${conditionSummary}<br>
                    THEN: ${this.escapeHtml(rule.then.decision)} (weight: ${rule.then.weight || 'default'})
                </div>
            `;

            ruleCard.querySelector('.edit-btn').addEventListener('click', () => this.openRuleModal(index));
            ruleCard.querySelector('.delete-btn').addEventListener('click', () => this.deleteRule(index));

            container.appendChild(ruleCard);
        });
    }

    getConditionSummary(condition) {
        if (condition.field) {
            const valueText = condition.value !== undefined ? ` "${this.escapeHtml(JSON.stringify(condition.value))}"` : '';
            return `${this.escapeHtml(condition.field)} ${condition.op}${valueText}`;
        } else if (condition.all) {
            return `ALL (${condition.all.length} conditions)`;
        } else if (condition.any) {
            return `ANY (${condition.any.length} conditions)`;
        }
        return 'unknown';
    }

    deleteRule(index) {
        if (confirm('Are you sure you want to delete this rule?')) {
            this.rules.splice(index, 1);
            this.renderRules();
            this.updateJSONPreview();
        }
    }

    updateJSONPreview() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';

        const output = {
            version: version,
            ruleset: ruleset,
            rules: this.rules
        };

        document.getElementById('jsonOutput').textContent = JSON.stringify(output, null, 2);
    }

    async validateRules() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';

        const payload = {
            version: version,
            ruleset: ruleset,
            rules: this.rules
        };

        try {
            const response = await fetch(`${this.basePath}api/validate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            const result = await response.json();

            if (result.valid) {
                this.showValidationSuccess();
            } else {
                this.showValidationErrors(result.errors);
            }
        } catch (error) {
            console.error('Validation error:', error);
            this.showValidationErrors(['Network error: Could not connect to validation server']);
        }
    }

    showValidationSuccess() {
        const statusEl = document.getElementById('validationStatus');
        const errorsEl = document.getElementById('validationErrors');

        statusEl.className = 'validation-status success';
        statusEl.querySelector('.status-message').textContent = 'All rules are valid!';
        statusEl.classList.remove('hidden');

        errorsEl.classList.add('hidden');
    }

    showValidationErrors(errors) {
        const statusEl = document.getElementById('validationStatus');
        const errorsEl = document.getElementById('validationErrors');
        const errorList = document.getElementById('errorList');

        statusEl.className = 'validation-status error';
        statusEl.querySelector('.status-message').textContent = 'Validation failed. See errors below.';
        statusEl.classList.remove('hidden');

        errorList.innerHTML = '';
        errors.forEach(error => {
            const li = document.createElement('li');
            li.textContent = error;
            errorList.appendChild(li);
        });

        errorsEl.classList.remove('hidden');
    }

    clearAll() {
        if (confirm('Are you sure you want to clear all rules?')) {
            this.rules = [];
            this.renderRules();
            this.updateJSONPreview();
            document.getElementById('validationStatus').classList.add('hidden');
            document.getElementById('validationErrors').classList.add('hidden');
        }
    }

    copyJSON() {
        const jsonText = document.getElementById('jsonOutput').textContent;
        navigator.clipboard.writeText(jsonText).then(() => {
            const btn = document.getElementById('copyBtn');
            const originalText = btn.textContent;
            btn.textContent = '✓ Copied!';
            setTimeout(() => {
                btn.textContent = originalText;
            }, 2000);
        });
    }

    downloadJSON() {
        const jsonText = document.getElementById('jsonOutput').textContent;
        const blob = new Blob([jsonText], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `rules_${new Date().getTime()}.json`;
        a.click();
        URL.revokeObjectURL(url);
    }

    importJSON(event) {
        const file = event.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const data = JSON.parse(e.target.result);

                if (data.rules && Array.isArray(data.rules)) {
                    this.rules = data.rules;

                    if (data.version) {
                        document.getElementById('rulesetVersion').value = data.version;
                    }
                    if (data.ruleset) {
                        document.getElementById('rulesetName').value = data.ruleset;
                    }

                    this.renderRules();
                    this.updateJSONPreview();
                    alert('Rules imported successfully!');
                } else {
                    alert('Invalid JSON format. Expected "rules" array.');
                }
            } catch (error) {
                alert('Error parsing JSON: ' + error.message);
            }
        };
        reader.readAsText(file);

        // Reset input
        event.target.value = '';
    }

    loadExample() {
        const example = {
            version: '1.0',
            ruleset: 'example_advanced_rules',
            rules: [
                {
                    id: 'corporate_email_approval',
                    if: {
                        all: [
                            { field: 'email', op: 'ends_with', value: '@company.com' },
                            { field: 'age', op: 'between', value: [18, 65] }
                        ]
                    },
                    then: {
                        decision: 'approve',
                        weight: 0.95,
                        reason: 'Corporate email with valid age range'
                    }
                },
                {
                    id: 'weekend_special_offer',
                    if: {
                        all: [
                            { field: 'booking_date', op: 'day_of_week', value: 'saturday' },
                            { field: 'amount', op: 'between', value: [100, 500] }
                        ]
                    },
                    then: {
                        decision: 'apply_discount',
                        weight: 0.9,
                        reason: 'Weekend booking discount eligible'
                    }
                },
                {
                    id: 'local_delivery_zone',
                    if: {
                        field: 'delivery.location',
                        op: 'within_radius',
                        value: { center: { lat: 40.7128, lon: -74.0060 }, radius: 25 }
                    },
                    then: {
                        decision: 'same_day_delivery',
                        weight: 0.85,
                        reason: 'Within local delivery zone'
                    }
                },
                {
                    id: 'permission_check',
                    if: {
                        all: [
                            { field: 'user.permissions', op: 'contains_all', value: ['read', 'write'] },
                            { field: 'user.roles', op: 'contains_any', value: ['admin', 'manager'] }
                        ]
                    },
                    then: {
                        decision: 'grant_access',
                        weight: 1.0,
                        reason: 'User has required permissions and role'
                    }
                },
                {
                    id: 'urgent_recent_account',
                    if: {
                        all: [
                            { field: 'message', op: 'contains', value: 'urgent' },
                            { field: 'created_at', op: 'within_days', value: 30 }
                        ]
                    },
                    then: {
                        decision: 'escalate',
                        weight: 0.9,
                        reason: 'Urgent message from recent account'
                    }
                }
            ]
        };

        this.rules = example.rules;
        document.getElementById('rulesetVersion').value = example.version;
        document.getElementById('rulesetName').value = example.ruleset;

        this.renderRules();
        this.updateJSONPreview();
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = String(text);
        return div.innerHTML;
    }

    // ===== VERSION MANAGEMENT METHODS =====

    getRuleData() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';

        return {
            version: version,
            ruleset: ruleset,
            rules: this.rules
        };
    }

    openSaveVersionModal() {
        const ruleset = document.getElementById('rulesetName').value;
        if (!ruleset) {
            alert('Please enter a ruleset name before saving a version');
            return;
        }

        document.getElementById('saveVersionModal').classList.remove('hidden');
    }

    closeSaveVersionModal() {
        document.getElementById('saveVersionModal').classList.add('hidden');
        document.getElementById('versionChangelog').value = '';
    }

    async confirmSaveVersion() {
        const ruleset = document.getElementById('rulesetName').value;
        const createdBy = document.getElementById('versionCreatedBy').value;
        const changelog = document.getElementById('versionChangelog').value;

        const ruleData = this.getRuleData();

        try {
            const response = await fetch(`${this.basePath}api/versions`, {
                method: 'POST',
                headers: this.getAuthHeaders(),
                body: JSON.stringify({
                    rule_id: ruleset,
                    content: ruleData,
                    created_by: createdBy,
                    changelog: changelog
                })
            });

            if (response.ok) {
                const version = await response.json();
                alert(`Version ${version.version_number} saved successfully!`);
                this.closeSaveVersionModal();
                this.loadVersionHistory();
            } else {
                const error = await response.json();
                alert(`Error saving version: ${error.error}`);
            }
        } catch (error) {
            alert(`Error saving version: ${error.message}`);
        }
    }

    async loadVersionHistory() {
        const ruleset = document.getElementById('rulesetName').value;
        if (!ruleset) {
            document.getElementById('versionHistoryContainer').innerHTML =
                '<p class="empty-state">Enter a ruleset name to view version history</p>';
            return;
        }

        try {
            const response = await fetch(`${this.basePath}api/rules/${encodeURIComponent(ruleset)}/history`, {
                headers: this.getAuthHeaders()
            });
            if (response.ok) {
                const history = await response.json();
                this.displayVersionHistory(history);
            } else {
                document.getElementById('versionHistoryContainer').innerHTML =
                    '<p class="empty-state">No versions found for this ruleset</p>';
            }
        } catch (error) {
            document.getElementById('versionHistoryContainer').innerHTML =
                `<p class="error-message">Error loading versions: ${error.message}</p>`;
        }
    }

    displayVersionHistory(history) {
        const container = document.getElementById('versionHistoryContainer');

        if (!history.versions || history.versions.length === 0) {
            container.innerHTML = '<p class="empty-state">No versions yet. Save a version to get started.</p>';
            return;
        }

        let html = `
            <div class="version-stats">
                <div class="stat">
                    <span class="stat-label">Total Versions:</span>
                    <span class="stat-value">${history.total_versions}</span>
                </div>
                <div class="stat">
                    <span class="stat-label">Active Version:</span>
                    <span class="stat-value">${history.active_version ? history.active_version.version_number : 'None'}</span>
                </div>
            </div>
            <table class="version-table">
                <thead>
                    <tr>
                        <th>Version</th>
                        <th>Created By</th>
                        <th>Created At</th>
                        <th>Status</th>
                        <th>Changelog</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
        `;

        history.versions.forEach((version, index) => {
            const createdAt = new Date(version.created_at).toLocaleString();
            const statusClass = version.status === 'active' ? 'status-active' :
                               version.status === 'draft' ? 'status-draft' : 'status-archived';

            html += `
                <tr class="${version.status === 'active' ? 'active-version' : ''}">
                    <td><strong>v${version.version_number}</strong></td>
                    <td>${this.escapeHtml(version.created_by)}</td>
                    <td>${createdAt}</td>
                    <td><span class="status-badge ${statusClass}">${version.status}</span></td>
                    <td>${this.escapeHtml(version.changelog || '')}</td>
                    <td class="action-buttons">
                        <button class="btn btn-xs btn-secondary" onclick="ruleBuilder.loadVersion('${version.id}')">Load</button>
                        ${version.status !== 'active' ?
                          `<button class="btn btn-xs btn-primary" onclick="ruleBuilder.rollbackToVersion('${version.id}')">Rollback</button>` :
                          '<span class="active-badge">Active</span>'}
                        ${index < history.versions.length - 1 ?
                          `<button class="btn btn-xs btn-secondary" onclick="ruleBuilder.compareVersions('${version.id}', '${history.versions[index + 1].id}')">Compare</button>` : ''}
                        ${version.status !== 'active' ?
                          `<button class="btn btn-xs btn-danger" onclick="ruleBuilder.deleteVersion('${version.id}')">Delete</button>` : ''}
                    </td>
                </tr>
            `;
        });

        html += `
                </tbody>
            </table>
        `;

        container.innerHTML = html;
    }

    async loadVersion(versionId) {
        try {
            const response = await fetch(`${this.basePath}api/versions/${encodeURIComponent(versionId)}`, {
                headers: this.getAuthHeaders()
            });
            if (response.ok) {
                const version = await response.json();
                this.loadRulesFromVersion(version.content);
                alert(`Loaded version ${version.version_number}`);
            } else {
                alert('Error loading version');
            }
        } catch (error) {
            alert(`Error loading version: ${error.message}`);
        }
    }

    loadRulesFromVersion(content) {
        if (content.version) {
            document.getElementById('rulesetVersion').value = content.version;
        }
        if (content.ruleset) {
            document.getElementById('rulesetName').value = content.ruleset;
        }
        if (content.rules) {
            this.rules = content.rules;
            this.renderRules();
            this.updateJSONPreview();
        }
    }

    async rollbackToVersion(versionId) {
        if (!confirm('Are you sure you want to rollback to this version? This will create a new version.')) {
            return;
        }

        try {
            const performedBy = prompt('Enter your name:', 'system');
            if (!performedBy) return;

            const response = await fetch(`${this.basePath}api/versions/${encodeURIComponent(versionId)}/activate`, {
                method: 'POST',
                headers: this.getAuthHeaders(),
                body: JSON.stringify({ performed_by: performedBy })
            });

            if (response.ok) {
                const version = await response.json();
                alert(`Rolled back to version ${version.version_number}`);
                this.loadVersionHistory();
                this.loadVersion(versionId);
            } else {
                const error = await response.json();
                alert(`Error during rollback: ${error.error}`);
            }
        } catch (error) {
            alert(`Error during rollback: ${error.message}`);
        }
    }

    async compareVersions(versionId1, versionId2) {
        try {
            const response = await fetch(
                `${this.basePath}api/versions/${encodeURIComponent(versionId1)}/compare/${encodeURIComponent(versionId2)}`,
                {
                    headers: this.getAuthHeaders()
                }
            );

            if (response.ok) {
                const comparison = await response.json();
                this.displayComparison(comparison);
                document.getElementById('compareVersionsModal').classList.remove('hidden');
            } else {
                alert('Error comparing versions');
            }
        } catch (error) {
            alert(`Error comparing versions: ${error.message}`);
        }
    }

    displayComparison(comparison) {
        const container = document.getElementById('comparisonResult');
        const v1 = comparison.version_1;
        const v2 = comparison.version_2;
        const diff = comparison.differences;

        let html = `
            <div class="comparison-header">
                <div class="version-info">
                    <h3>Version ${v1.version_number}</h3>
                    <p>By ${this.escapeHtml(v1.created_by)} on ${new Date(v1.created_at).toLocaleString()}</p>
                </div>
                <div class="comparison-arrow">→</div>
                <div class="version-info">
                    <h3>Version ${v2.version_number}</h3>
                    <p>By ${this.escapeHtml(v2.created_by)} on ${new Date(v2.created_at).toLocaleString()}</p>
                </div>
            </div>

            <div class="comparison-content">
                <div class="comparison-section">
                    <h4>Version ${v1.version_number} Content:</h4>
                    <pre class="json-code">${JSON.stringify(v1.content, null, 2)}</pre>
                </div>
                <div class="comparison-section">
                    <h4>Version ${v2.version_number} Content:</h4>
                    <pre class="json-code">${JSON.stringify(v2.content, null, 2)}</pre>
                </div>
            </div>

            <div class="diff-summary">
                <h4>Changes Summary:</h4>
                <div class="diff-stats">
                    <span class="diff-added">+${diff.added.length} added</span>
                    <span class="diff-removed">-${diff.removed.length} removed</span>
                    <span class="diff-changed">${Object.keys(diff.changed).length} changed</span>
                </div>
            </div>
        `;

        container.innerHTML = html;
    }

    closeCompareModal() {
        document.getElementById('compareVersionsModal').classList.add('hidden');
    }

    getRulesJSON() {
        const version = document.getElementById('rulesetVersion').value || '1.0';
        const ruleset = document.getElementById('rulesetName').value || 'my_ruleset';
        const rules = this.rules.map(rule => ({
            id: rule.id,
            if: rule.if,
            then: rule.then
        }));

        return {
            version: version,
            ruleset: ruleset,
            rules: rules
        };
    }

    openTestRuleModal() {
        document.getElementById('testRuleModal').classList.remove('hidden');
        document.getElementById('testContext').value = '{}';
        document.getElementById('testResults').classList.add('hidden');
    }

    closeTestRuleModal() {
        document.getElementById('testRuleModal').classList.add('hidden');
    }

    async runTest() {
        const contextText = document.getElementById('testContext').value.trim();

        // Get current rules
        const rules = this.getRulesJSON();

        if (!rules || !rules.rules || rules.rules.length === 0) {
            alert('Please add at least one rule before testing');
            return;
        }

        let context;
        try {
            context = contextText ? JSON.parse(contextText) : {};
        } catch (e) {
            alert('Invalid JSON in context field: ' + e.message);
            return;
        }

        try {
            const response = await fetch(`${this.basePath}api/evaluate`, {
                method: 'POST',
                headers: this.getAuthHeaders(),
                body: JSON.stringify({
                    rules: rules,
                    context: context
                })
            });

            const data = await response.json();

            if (!response.ok || !data.success) {
                alert('Test failed: ' + (data.error || 'Unknown error'));
                return;
            }

            // Display results
            const resultsDiv = document.getElementById('testResults');
            resultsDiv.classList.remove('hidden');

            if (data.decision) {
                document.getElementById('testDecisionValue').textContent = data.decision;
                document.getElementById('testConfidenceValue').textContent = (data.confidence || 0).toFixed(3);
                document.getElementById('testReasonValue').textContent = data.reason || 'N/A';

                // Display explainability
                const becauseList = document.getElementById('testBecauseList');
                const failedList = document.getElementById('testFailedList');

                if (data.because && data.because.length > 0) {
                    becauseList.innerHTML = '';
                    data.because.forEach(condition => {
                        const li = document.createElement('li');
                        li.textContent = condition;
                        li.style.color = '#28a745';
                        becauseList.appendChild(li);
                    });
                    document.getElementById('testBecause').style.display = 'block';
                } else {
                    document.getElementById('testBecause').style.display = 'none';
                }

                if (data.failed_conditions && data.failed_conditions.length > 0) {
                    failedList.innerHTML = '';
                    data.failed_conditions.forEach(condition => {
                        const li = document.createElement('li');
                        li.textContent = condition;
                        li.style.color = '#dc3545';
                        failedList.appendChild(li);
                    });
                    document.getElementById('testFailedConditions').style.display = 'block';
                } else {
                    document.getElementById('testFailedConditions').style.display = 'none';
                }

                document.getElementById('testExplainability').style.display = 'block';
            } else {
                document.getElementById('testDecisionValue').textContent = 'No match';
                document.getElementById('testConfidenceValue').textContent = 'N/A';
                document.getElementById('testReasonValue').textContent = data.message || 'No rules matched';
                document.getElementById('testExplainability').style.display = 'none';
            }
        } catch (error) {
            alert('Error running test: ' + error.message);
        }
    }

    async deleteVersion(versionId) {
        if (!confirm('Are you sure you want to delete this version? This action cannot be undone.')) {
            return;
        }

        try {
            const response = await fetch(`${this.basePath}api/versions/${encodeURIComponent(versionId)}`, {
                method: 'DELETE',
                headers: this.getAuthHeaders()
            });

            if (response.ok) {
                alert('Version deleted successfully');
                this.loadVersionHistory();
            } else {
                const error = await response.json();
                alert(`Error deleting version: ${error.error}`);
            }
        } catch (error) {
            alert(`Error deleting version: ${error.message}`);
        }
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.ruleBuilder = new RuleBuilder();

    // Update JSON on metadata changes
    ['rulesetVersion', 'rulesetName'].forEach(id => {
        document.getElementById(id).addEventListener('input', () => {
            window.ruleBuilder.updateJSONPreview();
        });
    });
});
