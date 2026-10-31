# docmap.nvim — module map

> **Generated** by `docmap`. Do not edit by hand — run `:DocMap`
> (or `nvim --headless -l scripts/gen_map.lua`) to regenerate.

**6 modules** · 7 namespaces · 137 helper files

The [interactive map](index.html) has filtering, full descriptions and
source links; this page is the version the code host renders directly.


## Namespaces

```mermaid
flowchart LR
  nlua_docmap["docmap.nvim"]
  nlua_docmap_bindings["bindings"]
  nlua_docmap_bindings_usrcmds["usrcmdsbr/smallThe user commands: `:DocMap` and…/small"]
  nlua_docmap_config["configbr/smallResolving a full `Docmap.Opts` for a…/small"]
  nlua_docmap_core["core"]
  nlua_docmap_core_lang["lang"]
  nlua_docmap_core_render["render"]
  nlua_docmap_editor["editor"]
  nlua_docmap_editor_browse["browsebr/small`:DocBrowse` — the module map inside the…/small"]
  nlua_docmap_integrations["integrations"]
  nlua_docmap_mcp["mcpbr/smallAn MCP (Model Context Protocol) server…/small"]
  nlua_docmap_testing["testingbr/smallWhich specs does a change touch, and what…/small"]
  nlua_docmap --> nlua_docmap_bindings
  nlua_docmap_bindings --> nlua_docmap_bindings_usrcmds
  nlua_docmap --> nlua_docmap_config
  nlua_docmap --> nlua_docmap_core
  nlua_docmap_core --> nlua_docmap_core_lang
  nlua_docmap_core --> nlua_docmap_core_render
  nlua_docmap --> nlua_docmap_editor
  nlua_docmap_editor --> nlua_docmap_editor_browse
  nlua_docmap --> nlua_docmap_integrations
  nlua_docmap --> nlua_docmap_mcp
  nlua_docmap --> nlua_docmap_testing
```


## Dependencies

Which parts of the tree require which, rolled up to the second level.
The [interactive map](index.html)'s **Deps** view has this per module,
in both directions, with load-time and lazy requires told apart.

```mermaid
flowchart LR
  nlua_docmap_bindings_autocmds_lua["docmap.bindings.autocmds"]
  nlua_docmap_bindings_diagnostics_lua["docmap.bindings.diagnostics"]
  nlua_docmap_bindings_docs_lua["docmap.bindings.docs"]
  nlua_docmap_bindings_keymaps_lua["docmap.bindings.keymaps"]
  nlua_docmap_bindings_progress_lua["docmap.bindings.progress"]
  nlua_docmap_bindings_usrcmds["docmap.bindings.usrcmds"]
  nlua_docmap_config_DEFAULTS_lua["docmap.config.DEFAULTS"]
  nlua_docmap_config_file_lua["docmap.config.file"]
  nlua_docmap_core_annotate_lua["docmap.core.annotate"]
  nlua_docmap_core_api_lua["docmap.core.api"]
  nlua_docmap_core_artifact_lua["docmap.core.artifact"]
  nlua_docmap_core_bindings_lua["docmap.core.bindings"]
  nlua_docmap_core_calls_lua["docmap.core.calls"]
  nlua_docmap_core_check_lua["docmap.core.check"]
  nlua_docmap_core_check_policy_lua["docmap.core.check_policy"]
  nlua_docmap_core_checklist_lua["docmap.core.checklist"]
  nlua_docmap_core_churn_lua["docmap.core.churn"]
  nlua_docmap_core_cli_lua["docmap.core.cli"]
  nlua_docmap_core_consumers_lua["docmap.core.consumers"]
  nlua_docmap_core_coverage_lua["docmap.core.coverage"]
  nlua_docmap_core_deps_lua["docmap.core.deps"]
  nlua_docmap_core_diff_lua["docmap.core.diff"]
  nlua_docmap_core_doccoverage_lua["docmap.core.doccoverage"]
  nlua_docmap_core_docs_lua["docmap.core.docs"]
  nlua_docmap_core_endpoint_coverage_lua["docmap.core.endpoint_coverage"]
  nlua_docmap_core_endpoints_lua["docmap.core.endpoints"]
  nlua_docmap_core_features_lua["docmap.core.features"]
  nlua_docmap_core_find_lua["docmap.core.find"]
  nlua_docmap_core_findings_lua["docmap.core.findings"]
  nlua_docmap_core_functions_lua["docmap.core.functions"]
  nlua_docmap_core_history_lua["docmap.core.history"]
  nlua_docmap_core_json_lua["docmap.core.json"]
  nlua_docmap_core_lang["lang"]
  nlua_docmap_core_lang_registry_lua["docmap.core.lang_registry"]
  nlua_docmap_core_loaded_diff_lua["docmap.core.loaded_diff"]
  nlua_docmap_core_markers_lua["docmap.core.markers"]
  nlua_docmap_core_plugins_lua["docmap.core.plugins"]
  nlua_docmap_core_quicks_lua["docmap.core.quicks"]
  nlua_docmap_core_render["render"]
  nlua_docmap_core_rules_api_lua["docmap.core.rules_api"]
  nlua_docmap_core_rules_join_lua["docmap.core.rules_join"]
  nlua_docmap_core_safe_fs_lua["docmap.core.safe_fs"]
  nlua_docmap_core_safe_out_dir_lua["docmap.core.safe_out_dir"]
  nlua_docmap_core_scan_lua["docmap.core.scan"]
  nlua_docmap_core_scopes_lua["docmap.core.scopes"]
  nlua_docmap_core_snippet_lua["docmap.core.snippet"]
  nlua_docmap_core_soft_require_lua["docmap.core.soft_require"]
  nlua_docmap_core_startup_graph_lua["docmap.core.startup_graph"]
  nlua_docmap_core_symbols_lua["docmap.core.symbols"]
  nlua_docmap_core_tagfiles_lua["docmap.core.tagfiles"]
  nlua_docmap_core_tags_lua["docmap.core.tags"]
  nlua_docmap_core_telemetry_join_lua["docmap.core.telemetry_join"]
  nlua_docmap_core_telemetry_self_lua["docmap.core.telemetry_self"]
  nlua_docmap_core_timing_lua["docmap.core.timing"]
  nlua_docmap_core_tools_lua["docmap.core.tools"]
  nlua_docmap_core_traffic_join_lua["docmap.core.traffic_join"]
  nlua_docmap_editor_browse["docmap.editor.browse"]
  nlua_docmap_editor_callhierarchy_lua["docmap.editor.callhierarchy"]
  nlua_docmap_editor_command_lua["docmap.editor.command"]
  nlua_docmap_editor_health_lua["docmap.editor.health"]
  nlua_docmap_editor_pick_lua["docmap.editor.pick"]
  nlua_docmap_editor_registry_lua["docmap.editor.registry"]
  nlua_docmap_editor_serve_lua["docmap.editor.serve"]
  nlua_docmap_integrations_menu_lua["docmap.integrations.menu"]
  nlua_docmap_mcp_protocol_lua["docmap.mcp.protocol"]
  nlua_docmap_mcp_tools_lua["docmap.mcp.tools"]
  nlua_docmap_testing_freshness_lua["docmap.testing.freshness"]
  nlua_docmap_testing_git_lua["docmap.testing.git"]
  nlua_docmap_testing_specs_lua["docmap.testing.specs"]
  nlua_docmap_bindings_autocmds_lua --> nlua_docmap_bindings_usrcmds
  nlua_docmap_bindings_diagnostics_lua --> nlua_docmap_core_findings_lua
  nlua_docmap_bindings_docs_lua --> nlua_docmap_bindings_autocmds_lua
  nlua_docmap_bindings_docs_lua --> nlua_docmap_editor_browse
  nlua_docmap_bindings_progress_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_bindings_progress_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_config_DEFAULTS_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_annotate_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_calls_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_check_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_checklist_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_churn_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_consumers_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_deps_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_diff_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_find_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_findings_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_history_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_telemetry_self_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_core_timing_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_editor_browse
  nlua_docmap_bindings_usrcmds --> nlua_docmap_editor_pick_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_editor_registry_lua
  nlua_docmap_bindings_usrcmds --> nlua_docmap_editor_serve_lua
  nlua_docmap_config_file_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_annotate_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_annotate_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_artifact_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_checklist_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_history_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_loaded_diff_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_rules_api_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_api_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_core_artifact_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_calls_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_core_calls_lua --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_check_policy_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_consumers_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_docs_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_loaded_diff_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_scopes_lua
  nlua_docmap_core_check_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_core_checklist_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_churn_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_artifact_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_coverage_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_diff_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_doccoverage_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_findings_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_render
  nlua_docmap_core_cli_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_safe_out_dir_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_scopes_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_startup_graph_lua
  nlua_docmap_core_cli_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_core_consumers_lua --> nlua_docmap_core_artifact_lua
  nlua_docmap_core_coverage_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_deps_lua --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_diff_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_diff_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_core_doccoverage_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_doccoverage_lua --> nlua_docmap_core_render
  nlua_docmap_core_docs_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_endpoint_coverage_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_features_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_find_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_bindings_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_calls_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_plugins_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_scan_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_snippet_lua
  nlua_docmap_core_functions_lua --> nlua_docmap_core_symbols_lua
  nlua_docmap_core_history_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_core_history_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_core_lang --> nlua_docmap_core_endpoints_lua
  nlua_docmap_core_lang --> nlua_docmap_core_functions_lua
  nlua_docmap_core_lang --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_lang --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_lang --> nlua_docmap_core_scan_lua
  nlua_docmap_core_lang --> nlua_docmap_core_snippet_lua
  nlua_docmap_core_loaded_diff_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_loaded_diff_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_quicks_lua --> nlua_docmap_core_doccoverage_lua
  nlua_docmap_core_render --> nlua_docmap_core_check_lua
  nlua_docmap_core_render --> nlua_docmap_core_docs_lua
  nlua_docmap_core_render --> nlua_docmap_core_findings_lua
  nlua_docmap_core_render --> nlua_docmap_core_json_lua
  nlua_docmap_core_render --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_render --> nlua_docmap_core_markers_lua
  nlua_docmap_core_render --> nlua_docmap_core_startup_graph_lua
  nlua_docmap_core_render --> nlua_docmap_core_tags_lua
  nlua_docmap_core_rules_api_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_rules_join_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_bindings_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_calls_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_markers_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_plugins_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_scan_lua --> nlua_docmap_core_snippet_lua
  nlua_docmap_core_startup_graph_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_symbols_lua --> nlua_docmap_core_scan_lua
  nlua_docmap_core_tagfiles_lua --> nlua_docmap_core_find_lua
  nlua_docmap_core_telemetry_join_lua --> nlua_docmap_core_check_lua
  nlua_docmap_core_telemetry_join_lua --> nlua_docmap_core_doccoverage_lua
  nlua_docmap_core_telemetry_join_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_telemetry_self_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_tools_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_core_tools_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_core_traffic_join_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_editor_browse --> nlua_docmap_bindings_keymaps_lua
  nlua_docmap_editor_browse --> nlua_docmap_bindings_usrcmds
  nlua_docmap_editor_browse --> nlua_docmap_core_artifact_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_check_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_deps_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_endpoint_coverage_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_history_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_loaded_diff_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_rules_join_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_safe_out_dir_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_soft_require_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_editor_browse --> nlua_docmap_core_traffic_join_lua
  nlua_docmap_editor_browse --> nlua_docmap_editor_command_lua
  nlua_docmap_editor_browse --> nlua_docmap_editor_registry_lua
  nlua_docmap_editor_browse --> nlua_docmap_integrations_menu_lua
  nlua_docmap_editor_callhierarchy_lua --> nlua_docmap_config_DEFAULTS_lua
  nlua_docmap_editor_callhierarchy_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_editor_command_lua --> nlua_docmap_bindings_usrcmds
  nlua_docmap_editor_command_lua --> nlua_docmap_core_find_lua
  nlua_docmap_editor_health_lua --> nlua_docmap_core_lang_registry_lua
  nlua_docmap_editor_health_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_editor_health_lua --> nlua_docmap_core_safe_out_dir_lua
  nlua_docmap_editor_health_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_editor_pick_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_editor_registry_lua --> nlua_docmap_bindings_diagnostics_lua
  nlua_docmap_editor_registry_lua --> nlua_docmap_core_render
  nlua_docmap_editor_registry_lua --> nlua_docmap_core_soft_require_lua
  nlua_docmap_editor_registry_lua --> nlua_docmap_core_telemetry_join_lua
  nlua_docmap_editor_registry_lua --> nlua_docmap_editor_callhierarchy_lua
  nlua_docmap_editor_serve_lua --> nlua_docmap_core_api_lua
  nlua_docmap_editor_serve_lua --> nlua_docmap_core_safe_fs_lua
  nlua_docmap_editor_serve_lua --> nlua_docmap_core_safe_out_dir_lua
  nlua_docmap_mcp_protocol_lua --> nlua_docmap_mcp_tools_lua
  nlua_docmap_mcp_tools_lua --> nlua_docmap_core_checklist_lua
  nlua_docmap_mcp_tools_lua --> nlua_docmap_core_findings_lua
  nlua_docmap_mcp_tools_lua --> nlua_docmap_core_json_lua
  nlua_docmap_testing_freshness_lua --> nlua_docmap_testing_git_lua
  nlua_docmap_testing_specs_lua --> nlua_docmap_core_deps_lua
  nlua_docmap_testing_specs_lua --> nlua_docmap_core_safe_fs_lua
```


## Modules

| Module | Description | Fns | Docs |
|---|---|---|---|
| `bindings` |  |  |  |
| &nbsp;&nbsp;`docmap.bindings.usrcmds` | The user commands: `:DocMap` and `:DocBrowse` — registration, argument dispatch and completion. | 7 | [README](../../lua/docmap/bindings/usrcmds/README.md) · [src](../../lua/docmap/bindings/usrcmds/init.lua) |
| `docmap.config` | Resolving a full `Docmap.Opts` for a repository: the defaults in [`DEFAULTS.lua`](../../lua/docmap/config/DEFAULTS.lua), what can be derived from `root`, and the merge rule every… | 7 | [README](../../lua/docmap/config/README.md) · [src](../../lua/docmap/config/init.lua) |
| `core` |  |  | [README](../../lua/docmap/core/README.md) |
| &nbsp;&nbsp;`lang` |  |  |  |
| &nbsp;&nbsp;&nbsp;&nbsp;`glossary` |  |  |  |
| &nbsp;&nbsp;`render` |  |  |  |
| `editor` |  |  | [README](../../lua/docmap/editor/README.md) |
| &nbsp;&nbsp;`docmap.editor.browse` | `:DocBrowse` — the module map inside the editor. | 42 | [README](../../lua/docmap/editor/browse/README.md) · [src](../../lua/docmap/editor/browse/init.lua) |
| `integrations` |  |  |  |
| `docmap.mcp` | An MCP (Model Context Protocol) server exposing this repository's module map to a coding agent. | 1 | [src](../../lua/docmap/mcp/init.lua) |
| `docmap.testing` | Which specs does a change touch, and what do the specs say about the map. | 20 | [README](../../lua/docmap/testing/README.md) · [src](../../lua/docmap/testing/init.lua) |

## Drift

0 errors · 0 warnings · 30 info

No errors or warnings.


<details>
<summary>30 informational findings</summary>


| Check | Message |
|---|---|
| `dead-function` | M._reset is marked @internal and nothing in the tree calls it |
| `undocumented-param` | M.rank has 4 parameter(s) but only 3 @param line(s) |
| `undocumented-param` | complexity has 3 parameter(s) but only 2 @param line(s) |
| `undocumented-param` | is_ignorable has 2 parameter(s) but only 0 @param line(s) |
| `unreferenced-module` | docmap.bindings.docs is required by no other file in the tree |
| `unreferenced-module` | docmap.core.config is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.asm is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.c is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.cpp is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.csharp is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.dart is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.elixir is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.erlang is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.go is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.haskell is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.java is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.js is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.kotlin is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.lua is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.ocaml is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.php is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.python is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.ruby is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.rust is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.scala is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.swift is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.ts is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.tsx is required by no other file in the tree |
| `unreferenced-module` | docmap.core.lang.zig is required by no other file in the tree |
| `unreferenced-module` | docmap.mcp is required by no other file in the tree |

</details>
