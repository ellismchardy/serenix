# When to mock

Mock at **system boundaries** only:
- External APIs (payments, email, third-party services)
- Databases — sometimes; prefer a real test DB
- Time and randomness
- The file system — sometimes

Don't mock your own modules, internal collaborators, or anything else you control.
Don't mock what you don't own without a thin wrapper of your own (see `docs/conventions.md`).

## Design boundaries to be mockable

**Inject dependencies instead of creating them:**

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**Prefer SDK-style wrappers over one generic fetcher:**

```typescript
// GOOD: each operation is independently mockable and typed
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// BAD: the mock needs conditional logic to fake each endpoint
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

Each mock then returns one specific shape, test setup has no branching, and it's obvious which
endpoints a test exercises.
