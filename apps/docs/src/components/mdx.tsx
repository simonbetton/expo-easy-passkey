import {
  createFileSystemGeneratorCache,
  createGenerator,
} from "fumadocs-typescript";
import { AutoTypeTable } from "fumadocs-typescript/ui";
import type { AutoTypeTableProps } from "fumadocs-typescript/ui";
import { Accordion, Accordions } from "fumadocs-ui/components/accordion";
import { CodeBlock, Pre } from "fumadocs-ui/components/codeblock";
import * as TabsComponents from "fumadocs-ui/components/tabs";
import defaultMdxComponents from "fumadocs-ui/mdx";
import type { MDXComponents } from "mdx/types";
import type { ComponentProps } from "react";

const generator = createGenerator({
  cache: createFileSystemGeneratorCache(".next/fumadocs-typescript"),
});

const PreComponent = ({
  ref: _ref,
  ...props
}: ComponentProps<"pre"> & { ref?: unknown }) => (
  <CodeBlock {...props}>
    <Pre>{props.children}</Pre>
  </CodeBlock>
);

export const getMDXComponents = (components?: MDXComponents) =>
  ({
    ...defaultMdxComponents,
    ...TabsComponents,
    Accordion,
    Accordions,
    AutoTypeTable: (props: Partial<AutoTypeTableProps>) => (
      <AutoTypeTable {...props} generator={generator} />
    ),
    pre: PreComponent,
    ...components,
  }) satisfies MDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
