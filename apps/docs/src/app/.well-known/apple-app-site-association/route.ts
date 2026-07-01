const appleAppSiteAssociation = {
  webcredentials: {
    apps: ["DA982D649A.dev.simonbetton.expoeasypasskey.example"],
  },
};

export const GET = () =>
  Response.json(appleAppSiteAssociation, {
    headers: {
      "Cache-Control": "public, max-age=300",
      "Content-Type": "application/json",
    },
  });
