# Html Summary
SwiftUI app based on [langchain-swift](https://github.com/buhe/langchain-swift).

If you find it troublesome or want to support me, go to apps.apple.com/us/app/ai-pagily/id6452588389

Edit it: https://github.com/buhe/HtmlSummary/blob/main/ShareExt/env.txt , set your openai_key.
## Core Code
```swift
  let loader = HtmlLoader(html: plain, url: url)
  let doc = await loader.load()
  let p = """
以下はページの内容です:%@、100語以内のメインコンテンツを要約してください。
"""
  let prompt = PromptTemplate(input_variables: ["youtube"], template: p)
  let request = prompt.format(args: [String(doc.first!.page_content.prefix(2000))])
  let llm = OpenAI()
  let reply = await llm.send(text: request)
```
