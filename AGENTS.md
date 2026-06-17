# Emacs config guidelines

## Keybinding antipatterns

| Trap                | Why it kills configs                                                                                                           |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **The junk drawer** | `SPC m` for "misc." Everything goes there. You forget what you bound.                                                          |
| **Category bleed**  | Putting `, s` for save-buffer under buffer leader. Save is a **file** action, not a buffer action. It breaks the mental model. |
| **Verb-first**      | `; o` for "open" (open what? file? buffer? org?). Namespaces must be nouns.                                                    |
| **Over-promotion**  | Giving a single-prefix leader to a category you use twice a day. It wastes mental space and which-key clutter.                 |

## Speed dial design principle

| Leader | Role | Mental model |
| ------ | ---- | ------------ |
| `-`    | navigation | Starts from **structured containers**: file trees, projects, perspectives. "Show me the structure, I'll pick." |
| `,`    | search     | Starts from **unstructured queries**: text patterns, buffer names, error lists. "I have a pattern, find matches." |

The distinction: `-` browses structure. `,` matches content. Both reach the same destinations. The difference is starting intent.

Verb-namespaces ("search") are acceptable when the verb is unambiguous and spans multiple nouns. "Search" means one thing. "Open" means nothing without a noun.
