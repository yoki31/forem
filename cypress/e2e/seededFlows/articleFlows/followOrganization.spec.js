describe('Follow an organization from article sidebar', () => {
  beforeEach(() => {
    cy.testSetup();
    cy.viewport('macbook-16');
    cy.fixture('users/articleEditorV1User.json').as('user');

    cy.intercept('GET', '/follows/*').as('follows');
    cy.get('@user').then((user) => {
      cy.loginAndVisit(user, '/admin_mcadmin/test-organization-article-slug');
    });
    cy.wait('@follows');
    cy.get('[data-follow-clicks-initialized]');
    cy.findByRole('heading', { name: 'Organization test article' });
  });

  it('Follows and unfollow an organization from the sidebar', () => {
    cy.intercept('/follows').as('followRequest');

    cy.contains('Follow').as('followButton');

    // Follow
    cy.get('@followButton').click();
    cy.wait('@followRequest');
    cy.get('@followButton').should('have.text', 'Following');
    cy.get('@followButton').should('have.attr', 'aria-pressed', 'true');

    // Check that the state persists after refresh
    cy.reload();
    cy.get('@followButton').should('have.text', 'Following');
    cy.get('@followButton').should('have.attr', 'aria-pressed', 'true');

    // Go to dashboard and check under 'Following Organizations'
    cy.visitAndWaitForUserSideEffects('/dashboard/following_organizations');
    cy.findByRole('main')
      .findByRole('link', { name: 'Bachmanity' })
      .should('exist');

    // Unfollow
    cy.visitAndWaitForUserSideEffects(
      '/admin_mcadmin/test-organization-article-slug',
    );
    // cy.intercept('/follows').as('followRequest');
    cy.contains('Following').as('followButton');
    cy.get('@followButton').click();
    cy.wait('@followRequest');
    cy.contains('Following').should('not.exist');
    cy.contains('Follow').as('followButton');
    cy.get('@followButton').should('have.text', 'Follow');
    cy.get('@followButton').should('have.attr', 'aria-pressed', 'false');

    // Check that the state persists after refresh
    cy.reload();
    cy.get('@followButton').should('have.text', 'Follow');
    cy.get('@followButton').should('have.attr', 'aria-pressed', 'false');

    // Go to dashboard and check under 'Following Organizations'
    cy.visitAndWaitForUserSideEffects('/dashboard/following_organizations');
    cy.findByRole('main')
      .findByRole('link', { name: 'Bachmanity' })
      .should('not.exist');
  });
});
