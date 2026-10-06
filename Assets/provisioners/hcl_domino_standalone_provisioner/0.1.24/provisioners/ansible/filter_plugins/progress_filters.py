import os
import yaml
from ansible.errors import AnsibleFilterError
from ansible.utils.display import Display

display = Display()

class FilterModule(object):
    def filters(self):
        return {
            'resolve_progress_dependencies': self.resolve_progress_dependencies
        }

    def _get_role_fqcn_parts(self, role_name_str):
        """Splits a role name (potentially FQCN) into (namespace, collection, simple_name)"""
        parts = role_name_str.split('.')
        if len(parts) >= 3:
            return parts[0], parts[1], '.'.join(parts[2:]) # Handles simple_name containing dots
        elif len(parts) == 1: # Simple name
            return None, None, parts[0]
        else: # Ambiguous, treat as simple for now or could be an error
            display.vvv(f"Ambiguous role name for FQCN parsing: {role_name_str}")
            return None, None, role_name_str


    def _get_role_meta(self, role_path):
        meta_file = os.path.join(role_path, 'meta', 'main.yml')
        if not os.path.exists(meta_file):
            display.vvv(f"Meta file not found: {meta_file}")
            return None
        try:
            with open(meta_file, 'r') as f:
                content = yaml.safe_load(f)
                display.vvv(f"Meta content for {role_path}: {content}")
                return content
        except Exception as e:
            display.warning(f"Error parsing meta file {meta_file}: {e}")
            return None

    def _get_role_defaults(self, role_path):
        defaults_file = os.path.join(role_path, 'defaults', 'main.yml')
        if not os.path.exists(defaults_file):
            display.vvv(f"Defaults file not found: {defaults_file}")
            return {}
        try:
            with open(defaults_file, 'r') as f:
                content = yaml.safe_load(f) or {}
                display.vvv(f"Defaults content for {role_path}: {content}")
                return content
        except Exception as e:
            display.warning(f"Error parsing defaults file {defaults_file}: {e}")
            return {}

    def resolve_progress_dependencies(self, initial_roles_config, playbook_dir, ansible_collections_base_relative_path):
        """
        :param initial_roles_config: List of role dicts from provision_roles
        :param playbook_dir: The directory of the playbook being run.
        :param ansible_collections_base_relative_path: Relative path from playbook_dir to the root of ansible_collections (e.g., '../ansible_collections')
        """
        display.v(f"Starting progress dependency resolution. Playbook dir: {playbook_dir}")
        display.v(f"Received initial_roles_config: {initial_roles_config}")
        display.v(f"Ansible collections base relative path: {ansible_collections_base_relative_path}")

        all_roles_data = {} # Keyed by FQCN
        abs_ansible_collections_base = os.path.normpath(os.path.join(playbook_dir, ansible_collections_base_relative_path))
        display.v(f"Absolute ansible_collections base path: {abs_ansible_collections_base}")

        if not os.path.isdir(abs_ansible_collections_base):
            display.error(f"Ansible collections base directory not found: {abs_ansible_collections_base}")
            return [] # Return empty if base collections dir is not found

        # Phase 1: Discover all roles by scanning the ansible_collections_base_path
        for namespace_name in os.listdir(abs_ansible_collections_base):
            namespace_path = os.path.join(abs_ansible_collections_base, namespace_name)
            if not os.path.isdir(namespace_path):
                continue
            
            for collection_name in os.listdir(namespace_path):
                collection_path = os.path.join(namespace_path, collection_name)
                if not os.path.isdir(collection_path):
                    continue
                
                abs_collection_roles_dir = os.path.join(collection_path, 'roles')
                display.v(f"Scanning for roles in: {abs_collection_roles_dir} (collection: {namespace_name}.{collection_name})")

                if not os.path.isdir(abs_collection_roles_dir):
                    display.vvv(f"No 'roles' directory in collection {namespace_name}.{collection_name} at {collection_path}")
                    continue

                for simple_role_name in os.listdir(abs_collection_roles_dir):
                    role_path = os.path.join(abs_collection_roles_dir, simple_role_name)
                    if os.path.isdir(role_path):
                        fqcn = f"{namespace_name}.{collection_name}.{simple_role_name}"
                        # This block should be nested to ensure fqcn is defined
                        if fqcn not in all_roles_data:
                            display.vv(f"Found role '{simple_role_name}' (FQCN: {fqcn}) at {role_path}")
                            meta_content = self._get_role_meta(role_path)
                            defaults_content = self._get_role_defaults(role_path)
                        all_roles_data[fqcn] = {
                            'path': role_path,
                            'meta': meta_content,
                            'defaults': defaults_content,
                            'name': simple_role_name, # Simple name
                            'fqcn': fqcn,
                            'namespace': namespace_name,
                            'collection': collection_name
                        }
        display.vvv(f"All discovered roles data (keyed by FQCN): {list(all_roles_data.keys())}")

        # Phase 2: Recursive resolution
        final_progress_definitions = []
        roles_to_process_queue = []
        for r_conf in initial_roles_config:
            if r_conf.get('enabled', True): # Default to enabled
                # r_conf['name'] is expected to be an FQCN from Hosts.yml
                roles_to_process_queue.append({'fqcn': r_conf['name'], 'source_vars': r_conf.get('vars', {})})
        
        counted_role_fqcns = set()
        explored_for_dependencies_fqcns = set()

        display.v(f"Initial processing queue: {roles_to_process_queue}")

        idx = 0
        while idx < len(roles_to_process_queue):
            current_task = roles_to_process_queue[idx]
            idx += 1
            
            current_fqcn = current_task['fqcn']
            source_vars = current_task['source_vars']

            display.vv(f"Processing '{current_fqcn}' from queue. Source vars: {source_vars}")

            if current_fqcn in counted_role_fqcns and current_fqcn in explored_for_dependencies_fqcns:
                display.vvv(f"'{current_fqcn}' already counted and explored. Skipping.")
                continue

            role_data = all_roles_data.get(current_fqcn)
            if not role_data:
                display.warning(f"Role '{current_fqcn}' (from provision_roles/dependency) not found in scanned collections. Skipping.")
                continue
            
            role_defaults = role_data.get('defaults', {})
            count_this_role_progress = source_vars.get('count_progress', role_defaults.get('count_progress', False))
            if isinstance(count_this_role_progress, str):
                count_this_role_progress = count_this_role_progress.lower() == 'true'

            display.vvv(f"Role '{current_fqcn}': count_progress={count_this_role_progress} (source: {source_vars.get('count_progress')}, default: {role_defaults.get('count_progress')})")

            if count_this_role_progress and current_fqcn not in counted_role_fqcns:
                progress_units = source_vars.get('progress_units', role_defaults.get('progress_units', 1))
                try:
                    progress_units = int(progress_units)
                except ValueError:
                    display.warning(f"Invalid progress_units '{progress_units}' for role '{current_fqcn}'. Defaulting to 1.")
                    progress_units = 1
                
                final_progress_definitions.append({'name': current_fqcn, 'progress_units': progress_units})
                counted_role_fqcns.add(current_fqcn)
                display.vv(f"Added '{current_fqcn}' to progress count with {progress_units} units.")

            if current_fqcn not in explored_for_dependencies_fqcns:
                explored_for_dependencies_fqcns.add(current_fqcn)
                meta = role_data.get('meta')
                if meta and 'dependencies' in meta and isinstance(meta['dependencies'], list):
                    for dep in meta['dependencies']:
                        dep_name_str = None
                        dep_vars = {}
                        if isinstance(dep, dict):
                            dep_name_str = dep.get('role')
                            dep_vars = {k: v for k, v in dep.items() if k != 'role'}
                        elif isinstance(dep, str):
                            dep_name_str = dep
                        
                        if not dep_name_str:
                            continue

                        dep_fqcn_to_queue = None
                        # Check if dep_name_str is already an FQCN
                        if '.' in dep_name_str and len(dep_name_str.split('.')) >= 3 : # Heuristic for FQCN
                            if dep_name_str in all_roles_data:
                                dep_fqcn_to_queue = dep_name_str
                            else:
                                display.vvv(f"Dependency '{dep_name_str}' looks like FQCN but not found in all_roles_data.")
                        else: # Simple name, try to resolve within current role's collection
                            parent_namespace = role_data.get('namespace')
                            parent_collection = role_data.get('collection')
                            if parent_namespace and parent_collection:
                                potential_fqcn = f"{parent_namespace}.{parent_collection}.{dep_name_str}"
                                if potential_fqcn in all_roles_data:
                                    dep_fqcn_to_queue = potential_fqcn
                                else:
                                    display.vvv(f"Simple dependency '{dep_name_str}' not found as '{potential_fqcn}' in same collection as '{current_fqcn}'.")
                            else:
                                display.vvv(f"Cannot resolve simple dependency '{dep_name_str}' for '{current_fqcn}' due to missing parent N/C info.")
                        
                        if dep_fqcn_to_queue:
                            is_in_queue = any(item['fqcn'] == dep_fqcn_to_queue for item in roles_to_process_queue[idx:])
                            if dep_fqcn_to_queue not in explored_for_dependencies_fqcns and not is_in_queue:
                                display.vvv(f"Queueing dependency '{dep_fqcn_to_queue}' of '{current_fqcn}' with vars {dep_vars}")
                                roles_to_process_queue.append({'fqcn': dep_fqcn_to_queue, 'source_vars': dep_vars})
                            else:
                                display.vvv(f"Dependency '{dep_fqcn_to_queue}' of '{current_fqcn}' already explored or in queue. Skipping queue add.")
                        else:
                            display.warning(f"Could not resolve dependency '{dep_name_str}' for role '{current_fqcn}'. Skipping.")
                else:
                    display.vvv(f"No dependencies found or meta missing for '{current_fqcn}'.")
            else:
                display.vvv(f"'{current_fqcn}' already explored for dependencies.")

        display.v(f"Final progress definitions: {final_progress_definitions}")
        return final_progress_definitions
