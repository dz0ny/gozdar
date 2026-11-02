// Site-wide identity. Feeds page titles, the meta description, and the
// Organization / WebSite JSON-LD.
export const SITE_NAME = "Gozdar";
export const SITE_DESCRIPTION =
	"Gozdar je terenska aplikacija za lastnike gozdov in gozdarje v Sloveniji: parcele s katastrom na karti, evidenca hlodovine, navigacija do mejnikov in karte brez signala.";

export const CONTACT_EMAIL = "hey@dz0ny.dev";
export const GITHUB_URL = "https://github.com/dz0ny/gozdar";
export const RELEASES_URL = "https://github.com/dz0ny/gozdar/releases";
export const LATEST_RELEASE_URL = "https://github.com/dz0ny/gozdar/releases/latest";
export const APP_STORE_URL = "https://apps.apple.com/app/id6756237942";
export const ISSUES_URL = "https://github.com/dz0ny/gozdar/issues";
export const NEW_ISSUE_URL = "https://github.com/dz0ny/gozdar/issues/new";

// Contact details for the Organization schema. Left null where unknown —
// the schema omits what isn't set rather than asserting something wrong.
export const SITE_CONTACT: {
	email: string | null;
	telephone: string | null;
	contactType: string;
	address: {
		streetAddress: string;
		addressLocality: string;
		postalCode: string;
		addressCountry: string;
	} | null;
	sameAs: string[];
} = {
	email: CONTACT_EMAIL,
	telephone: null,
	contactType: "customer support",
	address: null,
	sameAs: [GITHUB_URL],
};
