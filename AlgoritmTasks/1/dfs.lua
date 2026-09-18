local graph = {
  a = {"b", "c"},
  b = {"a", "d", "e"},
  c = {"a", "f"},
  d = {"b"},
  e = {"b", "f"},
  f = {"c", "e", "g"},
  g = {"f"},
}

local function dfs(start)
  local visited = {}
  local order = {}

  local function visit(node)
    if visited[node] then return end
    visited[node] = true
    table.insert(order, node)
    for _, neighbor in ipairs(graph[node] or {}) do
      visit(neighbor)
    end
  end

  visit(start)
  return order
end

local function joinList(list)
  return table.concat(list, " -> ")
end

print("DFS a")
print(joinList(dfs("a")))

print("DFS f")
print(joinList(dfs("f")))