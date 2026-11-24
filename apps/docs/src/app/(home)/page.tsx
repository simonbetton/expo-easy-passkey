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
          <p className="text-fd-muted-foreground mb-4 text-sm font-medium">
            Native passkeys for Expo apps
          </p>
          <h1 className="max-w-3xl text-4xl font-semibold tracking-tight text-balance sm:text-5xl lg:text-6xl">
            Add passkey registration and sign-in without leaving Expo.
          </h1>
          <p className="text-fd-muted-foreground mt-6 max-w-2xl text-lg leading-8">
            Expo Easy Passkey gives app developers a small TypeScript API over
            iOS AuthenticationServices and Android Credential Manager. Your app
            runs the native ceremony. Your server verifies the WebAuthn JSON.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link
              className="bg-fd-primary text-fd-primary-foreground rounded-full px-5 py-3 text-sm font-medium"
              href="/docs"
            >
              Read the docs
            </Link>
          </div>
        </div>

        <div className="bg-fd-card shadow-fd-primary/10 min-w-0 rounded-3xl border p-4 shadow-2xl">
          <pre className="bg-fd-muted overflow-x-auto rounded-2xl p-5 text-sm leading-7">
            <code>{`import {
  authenticateWithPasskey,
  createPasskey,
  getPasskeyAvailability,
} from "expo-easy-passkey";

const availability = getPasskeyAvailability();

if (availability.supported) {
  const { ceremonyId, options } = await fetchRegistrationOptions();
  const credential = await createPasskey(options);
  await verifyRegistration(ceremonyId, credential);

  const authentication = await fetchAuthenticationOptions();
  const assertion = await authenticateWithPasskey(authentication.options);
  await verifyAuthentication(authentication.ceremonyId, assertion);
}`}</code>
          </pre>
        </div>
      </section>

      <section className="mt-16 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {links.map((item) => (
          <Link
            className="bg-fd-card hover:bg-fd-accent rounded-2xl border p-5 transition-colors"
            href={item.href}
            key={item.href}
          >
            <h2 className="text-lg font-medium">{item.title}</h2>
            <p className="text-fd-muted-foreground mt-3 text-sm leading-6">
              {item.description}
            </p>
          </Link>
        ))}
      </section>
    </div>
  );
}
