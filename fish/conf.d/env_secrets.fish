# Load ~/.env_secrets (bash export syntax) into fish env
# and ensure ~/bin is on PATH

fish_add_path -g ~/bin

if test -f ~/.env_secrets
    for line in (grep -E '^\s*export\s+\w+=' ~/.env_secrets)
        set kv (string replace -r '^\s*export\s+' '' -- $line)
        set key (string split -m 1 '=' -- $kv)[1]
        set val (string split -m 1 '=' -- $kv)[2]
        # Strip surrounding single/double quotes if present
        set val (string replace -r '^"(.*)"$' '$1' -- $val)
        set val (string replace -r "^'(.*)'\$" '$1' -- $val)
        set -gx $key $val
    end
end
