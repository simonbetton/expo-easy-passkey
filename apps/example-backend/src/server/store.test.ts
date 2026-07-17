import { describe, expect, it } from "@jest/globals";

import { createDemoStore } from "./store.js";
import type { CeremonyKind } from "./store.js";

const ceremonyRef = (
  kind: CeremonyKind,
  ceremonyId: string,
  userId = "demo-user"
) => ({ ceremonyId, kind, userId });

describe("demo ceremony store", () => {
  it("keeps overlapping ceremonies distinct and consumes them in either order", () => {
    const ceremonyIds = ["registration-id", "authentication-id"];
    const store = createDemoStore({
      createCeremonyId: () => ceremonyIds.shift() ?? "unexpected-id",
      now: () => 1000,
    });

    const registrationId = store.createCeremony(
      "registration",
      "demo-user",
      "registration-challenge",
      60_000
    );
    const authenticationId = store.createCeremony(
      "authentication",
      "demo-user",
      "authentication-challenge",
      60_000
    );

    expect(authenticationId).not.toBe(registrationId);
    expect(
      store.getCeremonyChallenge(
        ceremonyRef("authentication", authenticationId)
      )
    ).toBe("authentication-challenge");
    store.consumeCeremony(
      ceremonyRef("authentication", authenticationId),
      "authentication-challenge"
    );
    expect(
      store.getCeremonyChallenge(ceremonyRef("registration", registrationId))
    ).toBe("registration-challenge");
    store.consumeCeremony(
      ceremonyRef("registration", registrationId),
      "registration-challenge"
    );

    expect(() =>
      store.getCeremonyChallenge(
        ceremonyRef("authentication", authenticationId)
      )
    ).toThrow("No matching passkey ceremony is pending.");
    expect(() =>
      store.getCeremonyChallenge(ceremonyRef("registration", registrationId))
    ).toThrow("No matching passkey ceremony is pending.");
  });

  it("does not consume a ceremony for the wrong kind, user, or challenge", () => {
    const store = createDemoStore({
      createCeremonyId: () => "registration-id",
      now: () => 1000,
    });
    const ceremonyId = store.createCeremony(
      "registration",
      "demo-user",
      "registration-challenge",
      60_000
    );

    expect(() =>
      store.consumeCeremony(
        ceremonyRef("authentication", ceremonyId),
        "registration-challenge"
      )
    ).toThrow("The passkey ceremony does not match this request.");
    expect(() =>
      store.consumeCeremony(
        ceremonyRef("registration", ceremonyId, "another-user"),
        "registration-challenge"
      )
    ).toThrow("The passkey ceremony does not match this request.");
    expect(() =>
      store.consumeCeremony(
        ceremonyRef("registration", ceremonyId),
        "another-challenge"
      )
    ).toThrow("The passkey ceremony challenge does not match.");

    expect(
      store.getCeremonyChallenge(ceremonyRef("registration", ceremonyId))
    ).toBe("registration-challenge");
  });

  it("rejects replay without disturbing another ceremony", () => {
    const ceremonyIds = ["first-id", "second-id"];
    const store = createDemoStore({
      createCeremonyId: () => ceremonyIds.shift() ?? "unexpected-id",
      now: () => 1000,
    });
    const firstId = store.createCeremony(
      "registration",
      "demo-user",
      "first-challenge",
      60_000
    );
    const secondId = store.createCeremony(
      "registration",
      "demo-user",
      "second-challenge",
      60_000
    );

    store.consumeCeremony(
      ceremonyRef("registration", firstId),
      "first-challenge"
    );

    expect(() =>
      store.consumeCeremony(
        ceremonyRef("registration", firstId),
        "first-challenge"
      )
    ).toThrow("No matching passkey ceremony is pending.");
    expect(
      store.getCeremonyChallenge(ceremonyRef("registration", secondId))
    ).toBe("second-challenge");
  });

  it("removes expired ceremonies while retaining unexpired records", () => {
    let currentTime = 1000;
    const ceremonyIds = ["expired-id", "active-id", "new-id"];
    const store = createDemoStore({
      createCeremonyId: () => ceremonyIds.shift() ?? "unexpected-id",
      now: () => currentTime,
    });
    const expiredId = store.createCeremony(
      "registration",
      "demo-user",
      "expired-challenge",
      10
    );
    const activeId = store.createCeremony(
      "authentication",
      "demo-user",
      "active-challenge",
      60_000
    );

    currentTime = 1011;
    store.createCeremony("registration", "demo-user", "new-challenge", 60_000);

    expect(() =>
      store.getCeremonyChallenge(ceremonyRef("registration", expiredId))
    ).toThrow("No matching passkey ceremony is pending.");
    expect(
      store.getCeremonyChallenge(ceremonyRef("authentication", activeId))
    ).toBe("active-challenge");
  });
});
