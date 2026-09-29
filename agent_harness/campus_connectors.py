"""Per-user, scope-checked extension point for future campus API connectors."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable
from pydantic import BaseModel, ValidationError


@dataclass(frozen=True)
class CampusPrincipal:
    user_id: str
    scopes: frozenset[str] = frozenset()


CampusHandler = Callable[[CampusPrincipal, BaseModel], Awaitable[dict[str, Any]]]


@dataclass(frozen=True)
class CampusOperation:
    name: str
    description: str
    required_scope: str
    arguments_model: type[BaseModel]
    handler: CampusHandler


@dataclass
class CampusConnectorRegistry:
    operations: dict[str, CampusOperation] = field(default_factory=dict)

    def register(self, operation: CampusOperation) -> None:
        self.operations[operation.name] = operation

    def available_to(self, principal: CampusPrincipal | None) -> list[dict[str, str]]:
        if principal is None:
            return []
        return [
            {
                "name": operation.name,
                "description": operation.description,
                "required_scope": operation.required_scope,
                "arguments_schema": operation.arguments_model.model_json_schema(),
            }
            for operation in self.operations.values()
            if operation.required_scope in principal.scopes
        ]

    async def call(
        self, principal: CampusPrincipal | None, name: str, arguments: dict[str, Any]
    ) -> dict[str, Any]:
        operation = self.operations.get(name)
        if operation is None:
            return {"error": "校园 API 尚未接入此功能。"}
        if principal is None or operation.required_scope not in principal.scopes:
            return {"error": "当前登录用户没有此校园 API 的授权范围。"}
        try:
            validated_arguments = operation.arguments_model.model_validate(arguments)
        except ValidationError as exc:
            return {"error": "校园 API 参数不符合要求。", "details": exc.errors(include_input=False)}
        return await operation.handler(principal, validated_arguments)


campus_connectors = CampusConnectorRegistry()
