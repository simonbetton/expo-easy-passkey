import Link from "next/link";

const links = [
  {
    description:
      "Install the packages, configure the plugin, and build a dev client.",
    href: "/docs/install",
    title: "Install",
  },
  {
    description:
      "Host AASA and Digital Asset Links files for your relying-party domain.",
    href: "/docs/platform",
    title: "Platforms",
  },
  {
    description:
      "Connect the app ceremony to challenge and verification endpoints.",
    href: "/docs/server",
    title: "Server",
  },
  {
    description:
      "Copy app-side recipes for registration, sign-in, fallback UI, and errors.",
    href: "/docs/examples",
    title: "Examples",
  },
];

export default function HomePage() {
  return (
    <div className="mx-auto flex w-full max-w-6xl flex-1 flex-col overflow-hidden px-6 py-16 sm:py-24">
      <section className="grid min-w-0 gap-10 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
        <div className="min-w-0">
          <p className="mb-4 font-medium text-fd-muted-foreground text-sm">
            Native passkeys for Expo apps
          </p>
          <h1 className="max-w-3xl text-balance font-semibold text-4xl tracking-tight sm:text-5xl lg:text-6xl">
            Add passkey registration and sign-in without leaving Expo.
          </h1>
          <p className="mt-6 max-w-2xl text-fd-muted-foreground text-lg leading-8">
            Expo Easy Passkey gives app developers a small TypeScript API over
            iOS AuthenticationServices and Android Credential Manager. Your app
            runs the native ceremony. Your server verifies the WebAuthn JSON.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              className="rounded-full bg-fd-primary px-5 py-3 font-medium text-fd-primary-foreground text-sm"
              href="/docs"
            >
              Read the docs
            </Link>
          </div>
        </div>

        <div className="min-w-0 rounded-3xl border bg-fd-card p-4 shadow-2xl shadow-fd-primary/10">
          <pre className="overflow-x-auto rounded-2xl bg-fd-muted p-5 text-sm leading-7">
            <code>{`import {
  authenticateWithPasskey,
  createPasskey,
  getPasskeyAvailability,
} from "expo-easy-passkey";

const availability = getPasskeyAvailability();

if (availability.supported) {
  const options = await fetchRegistrationOptions();
  const credential = await createPasskey(options);
  await verifyRegistration(credential);

  const request = await fetchAuthenticationOptions();
  const assertion = await authenticateWithPasskey(request);
  await verifyAuthentication(assertion);
}`}</code>
          </pre>
        </div>
      </section>

      <section className="mt-16 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {links.map((item) => (
          <Link
            className="rounded-2xl border bg-fd-card p-5 transition-colors hover:bg-fd-accent"
            href={item.href}
            key={item.href}
          >
            <h2 className="font-medium text-lg">{item.title}</h2>
            <p className="mt-3 text-fd-muted-foreground text-sm leading-6">
              {item.description}
            </p>
          </Link>
        ))}
      </section>
    </div>
  );
}
