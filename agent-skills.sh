#!/usr/bin/env bash
# Compatibility entrypoint for the provider-neutral agent-skills name.

_agent_skills_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
. "$_agent_skills_script_dir/hnl-claude-skills.sh"
unset _agent_skills_script_dir
