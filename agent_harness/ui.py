"""Versioned presentation descriptions with no executable code or model-supplied destinations."""
from __future__ import annotations

from typing import Annotated, Any, Literal
from urllib.parse import urlsplit

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, StringConstraints, TypeAdapter, ValidationError


def _plain(value: str) -> str:
    if '<' in value or '>' in value:
        raise ValueError('Display text must not contain markup')
    return value


Title = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=240), AfterValidator(_plain)]
Detail = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000), AfterValidator(_plain)]
Identifier = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100), AfterValidator(_plain)]
Citations = Annotated[list[Annotated[int, Field(strict=True, ge=1)]], Field(min_length=1, max_length=8)]


class UIModel(BaseModel):
    model_config = ConfigDict(extra='forbid')


class SourceList(UIModel):
    type: Literal['source_list']
    citations: Citations


class GuideStep(UIModel):
    title: Title
    detail: Detail
    citations: Citations


class Guide(UIModel):
    type: Literal['guide']
    title: Title
    steps: list[GuideStep] = Field(min_length=1, max_length=8)


class ServiceLinks(UIModel):
    type: Literal['service_links']
    serviceIds: list[Identifier] = Field(min_length=1, max_length=8)


UICard = Annotated[SourceList | Guide | ServiceLinks, Field(discriminator='type')]
card_adapter = TypeAdapter(UICard)


class UIEnvelope(UIModel):
    version: Literal[1]
    cards: list[UICard] = Field(min_length=1, max_length=3)


class UIService(UIModel):
    id: Identifier
    name: Title
    description: Detail


def card_citations(card: SourceList | Guide | ServiceLinks) -> set[int]:
    if isinstance(card, SourceList):
        return set(card.citations)
    if isinstance(card, Guide):
        return {number for step in card.steps for number in step.citations}
    return set()


def safe_source_url(value: str | None) -> bool:
    if value is None:
        return True
    try:
        url = urlsplit(value)
        return url.scheme in ('http', 'https') and bool(url.hostname) and not url.username and not url.password
    except ValueError:
        return False


def validate_ui(value: Any, sources: list[dict[str, Any]], service_ids: set[str],
                stale_citations: set[int] | None = None) -> tuple[UIEnvelope | None, list[str]]:
    if value is None:
        return None, []
    if (not isinstance(value, dict) or set(value) != {'version', 'cards'} or
            type(value.get('version')) is not int or value['version'] != 1 or
            not isinstance(value.get('cards'), list) or not 1 <= len(value['cards']) <= 3):
        return None, ['invalid_envelope']
    source_map = {source['citation']: source for source in sources}
    cards = []
    errors = []
    for index, raw in enumerate(value['cards']):
        try:
            card = card_adapter.validate_python(raw)
        except ValidationError:
            errors.append(f'card_{index}:invalid_schema')
            continue
        references = card_citations(card)
        if any(number not in source_map or not safe_source_url(source_map[number].get('source')) or
               number in (stale_citations or set()) for number in references):
            errors.append(f'card_{index}:invalid_source')
        elif isinstance(card, ServiceLinks) and any(name not in service_ids for name in card.serviceIds):
            errors.append(f'card_{index}:unknown_service')
        else:
            cards.append(card)
    return (UIEnvelope(version=1, cards=cards) if cards else None), errors
