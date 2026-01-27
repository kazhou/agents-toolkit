# Plan: auto-checklists Package Architecture & Implementation

## Overview

Build a Python package (similar to [judges](https://github.com/quotient-ai/judges)) that provides a library of checklist generation and scoring methods for LLM evaluation. Package-first with UI-aware design (Pydantic models, async support) for future React UI.

## Key Decisions

- **Model provider**: OpenRouter for unified access
- **Generation scope**: Both instance-level and corpus-level
- **Features**: Checklist generation + scoring
- **Architecture**: Re-implement core logic from papers in unified API

---

## Package Structure

```
auto_checklists/
├── __init__.py              # Main exports
├── models.py                # Pydantic data models
├── config.py                # Configuration (OpenRouter API key, defaults)
│
├── generators/
│   ├── __init__.py          # Registry & exports
│   ├── base.py              # ChecklistGenerator, InstanceGenerator, CorpusGenerator
│   ├── instance/
│   │   ├── tick.py          # [6] TICK - few-shot from instruction
│   │   ├── rlcf.py          # [5] RLCF - direct + candidate-based
│   │   └── rocketeval.py    # [3] RocketEval - query + reference
│   └── corpus/
│       ├── checkeval.py     # [2] CheckEval - dimensions + augmentation
│       ├── interacteval.py  # [4] InteractEval - think-aloud
│       └── feedback.py      # [1] Feedback-based
│
├── scorers/
│   ├── __init__.py
│   ├── base.py              # ChecklistScorer base class
│   ├── binary.py            # Simple yes/no proportion
│   ├── normalized.py        # RocketEval-style with logprobs
│   └── weighted.py          # Weighted scoring
│
├── providers/
│   ├── __init__.py
│   └── openrouter.py        # OpenRouter async client
│
├── prompts/
│   ├── __init__.py          # Template loading utilities
│   └── templates/           # .txt prompt files per method
│
└── utils/
    ├── io.py                # JSONL/JSON utilities
    └── parsing.py           # Response parsing helpers

tests/
├── test_generators/
├── test_scorers/
└── fixtures/
```

---

## Core Data Models (models.py)

```python
class ChecklistItem(BaseModel):
    id: str
    question: str  # Yes/no question
    weight: float = 1.0
    category: Optional[str] = None

class Checklist(BaseModel):
    id: str
    items: List[ChecklistItem]
    source_method: str  # "tick", "rlcf", "checkeval", etc.
    generation_level: str  # "instance" or "corpus"
    instruction: Optional[str] = None

class Score(BaseModel):
    checklist_id: str
    item_scores: List[ItemScore]  # Per-item yes/no/na + confidence
    total_score: float  # 0-1 proportion
    weighted_score: Optional[float] = None
```

---

## API Design

### Instance-level (per-input checklist)

```python
from auto_checklists import TICK, RLCF, RocketEval, BinaryScorer

# TICK - simplest, from instruction only
tick = TICK(model="openai/gpt-4o-mini")
checklist = tick.generate(instruction="Write a haiku about autumn.")

# RLCF - with candidate responses for failure mode detection
rlcf = RLCF(model="openai/gpt-4o", mode="candidate_based")
checklist = rlcf.generate(instruction="...", candidates=["...", "..."])

# RocketEval - with reference response
rocketeval = RocketEval(model="openai/gpt-4o")
checklist = rocketeval.generate(instruction="...", reference="...")

# Scoring
scorer = BinaryScorer(model="openai/gpt-4o-mini")
score = scorer.score(checklist, response="...")
print(score.total_score)  # 0.75
```

### Corpus-level (one checklist for dataset)

```python
from auto_checklists import CheckEval, FeedbackChecklist
from auto_checklists.models import DimensionInput, FeedbackInput

# CheckEval - from evaluation dimensions
checkeval = CheckEval(model="openai/gpt-4o")
checklist = checkeval.generate(
    dimensions=[
        DimensionInput(name="coherence", definition="..."),
        DimensionInput(name="relevance", definition="..."),
    ],
    augment=True,  # Diversification + elaboration
    filter=True,   # Alignment + consistency + deduplication
)

# Feedback-based - from user feedback corpus
feedback_gen = FeedbackChecklist(model="openai/gpt-4o")
checklist = feedback_gen.generate(
    feedback=[FeedbackInput(feedback_text="...", category="...")],
    merge_redundant=True,
)
```

### Custom generators

```python
from auto_checklists import InstanceChecklistGenerator

class MyGenerator(InstanceChecklistGenerator):
    def generate(self, instruction: str, **kwargs) -> Checklist:
        # Custom logic
        ...
```

---

## Implementation Order

### Phase 1: Foundation & Data Discovery
1. Pull latest from reference repos (RLCF, tick, CheckEval, RocketEval-ICLR, InteractEval)
2. **Explore repo test data** - identify example inputs for testing:
   - RLCF: WildChat samples, requirement generation examples
   - tick: InFoBench instruction samples
   - CheckEval: SummEval dimensions, sample summaries
   - RocketEval: MT-Bench/WildBench query samples
   - InteractEval: Think-aloud attributes, SummEval samples
3. Copy/reference relevant test data to `tests/fixtures/`
4. Set up package structure with `uv`
5. Implement `models.py` - Pydantic data models
6. Implement `config.py` - OpenRouter config
7. Implement `providers/openrouter.py` - async client

### Phase 2: Instance-level Generators (simpler)
6. Implement `generators/base.py` - base classes
7. Implement `generators/instance/tick.py` - TICK (simplest)
8. Implement `scorers/binary.py` - basic scorer
9. Write tests for TICK + BinaryScorer
10. Implement `generators/instance/rlcf.py` - RLCF (both modes)
11. Implement `generators/instance/rocketeval.py` - RocketEval
12. Implement `scorers/normalized.py` - for RocketEval

### Phase 3: Corpus-level Generators
13. Implement `generators/corpus/checkeval.py` - CheckEval
14. Implement `generators/corpus/feedback.py` - Feedback-based
15. Implement `generators/corpus/interacteval.py` - InteractEval
16. Implement `scorers/weighted.py` - weighted scoring

### Phase 4: Polish
17. Add batch processing utilities
18. Add CLI (optional)
19. Documentation & examples
20. Prepare for React UI integration

---

## Reference Repos to Pull

```bash
cd /data/karen/checklist_repos
git -C RLCF pull 2>/dev/null || git clone https://github.com/viswavi/RLCF/
git -C tick pull 2>/dev/null || git clone https://github.com/jonathan-cook235/tick
git -C CheckEval pull 2>/dev/null || git clone https://github.com/yukyunglee/CheckEval
git -C RocketEval-ICLR pull 2>/dev/null || git clone https://github.com/Joinn99/RocketEval-ICLR
git -C InteractEval pull 2>/dev/null || git clone https://github.com/BBeeChu/InteractEval
```

---

## Verification Plan

1. **Unit tests**: Test each generator and scorer with **real LLM calls** (cheap model like gpt-4o-mini) using test data from reference repos
2. **Test data**: Use actual samples from reference repos (InFoBench, WildChat, SummEval, etc.)
3. **Validation checks**:
   - Format: Are items yes/no questions? Within expected count range?
   - Parsing: Does response parsing handle actual LLM output formats?
   - Scoring: Does scoring produce valid 0-1 scores?
4. **Comparison**: Where possible, compare checklist outputs to reference repo outputs
5. **Example notebook**: Create Jupyter notebook demonstrating all methods

---

## Dependencies (pyproject.toml)

```toml
dependencies = [
    "pydantic>=2.0",
    "httpx>=0.25",
    "python-dotenv>=1.0",
    "tenacity>=8.0",
    "tqdm>=4.0",
]
```

---

## Critical Files to Modify/Create

- `auto_checklists/__init__.py` - main exports
- `auto_checklists/models.py` - data models
- `auto_checklists/config.py` - configuration
- `auto_checklists/generators/base.py` - base classes
- `auto_checklists/providers/openrouter.py` - LLM client
- `auto_checklists/generators/instance/tick.py` - first generator
- `auto_checklists/scorers/binary.py` - first scorer
- `pyproject.toml` - add dependencies
- `tests/test_generators/test_tick.py` - first tests
