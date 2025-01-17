import { h } from 'preact';
import { render } from '@testing-library/preact';
import fetch from 'jest-fetch-mock';
import '@testing-library/jest-dom';
import { axe } from 'jest-axe';

import { ProfileForm } from '../ProfileForm';

global.fetch = fetch;
global.Honeybadger = { notify: jest.fn() };

describe('ProfileForm', () => {
  const renderProfileForm = () =>
    render(
      <ProfileForm
        next={jest.fn()}
        prev={jest.fn()}
        currentSlideIndex={2}
        slidesCount={5}
        communityConfig={{
          communityName: 'Community Name',
          communityLogo: '/x.png',
          communityBackgroundColor: '#FFF000',
          communityDescription: 'Some community description',
        }}
        previousLocation={null}
      />,
    );

  const getUserData = () =>
    JSON.stringify({
      followed_tag_names: ['javascript'],
      profile_image_90: 'mock_url_link',
      name: 'firstname lastname',
      username: 'username',
    });

  const fakeGroupsResponse = JSON.stringify({
    profile_field_groups: [
      {
        id: 3,
        name: 'Work',
        description: null,
        profile_fields: [
          {
            id: 36,
            attribute_name: 'education',
            description: '',
            input_type: 'text_field',
            label: 'Education',
            placeholder_text: '',
          },
        ],
      },
      {
        id: 1,
        name: 'Basic',
        description: null,
        profile_fields: [
          {
            id: 31,
            attribute_name: 'name',
            description: '',
            input_type: 'text_field',
            label: 'Name',
            placeholder_text: 'John Doe',
          },
          {
            id: 32,
            attribute_name: 'website_url',
            description: '',
            input_type: 'text_field',
            label: 'Website URL',
            placeholder_text: 'https://yoursite.com',
          },
        ],
      },
    ],
  });

  beforeAll(() => {
    document.head.innerHTML =
      '<meta name="csrf-token" content="some-csrf-token" />';
    document.body.setAttribute('data-user', getUserData());
    fetch.mockResponse(fakeGroupsResponse);
    const csrfToken = 'this-is-a-csrf-token';
    global.getCsrfToken = async () => csrfToken;
  });

  it('should have no a11y violations', async () => {
    const { container } = renderProfileForm();
    const results = await axe(container);

    expect(results).toHaveNoViolations();
  });

  it('should load the appropriate title and subtitle', () => {
    const { getByTestId, getByText } = renderProfileForm();

    getByText(/Build your profile/i);
    expect(getByTestId('onboarding-profile-subtitle')).toHaveTextContent(
      /Tell us a little bit about yourself — this is how others will see you on Community Name. You’ll always be able to edit this later in your Settings./i,
    );
  });

  it('should render TextInput with placeholder text', () => {
    const { getByPlaceholderText } = render(
      <ProfileForm
        prev={jest.fn()}
        next={jest.fn()}
        slidesCount={3}
        currentSlideIndex={1}
        communityConfig={{ communityName: 'Community' }}
      />,
    );

    const usernameInput = getByPlaceholderText('johndoe');
    expect(usernameInput).toBeInTheDocument();
  });

  it('should render TextArea with placeholder text', () => {
    const { getByPlaceholderText } = render(
      <ProfileForm
        prev={jest.fn()}
        next={jest.fn()}
        slidesCount={3}
        currentSlideIndex={1}
        communityConfig={{ communityName: 'Community' }}
      />,
    );

    const bioTextArea = getByPlaceholderText('Tell us a little about yourself');
    expect(bioTextArea).toBeInTheDocument();
  });

  it('should render TextInput with input type "text"', () => {
    const { getByPlaceholderText } = render(
      <ProfileForm
        prev={jest.fn()}
        next={jest.fn()}
        slidesCount={3}
        currentSlideIndex={1}
        communityConfig={{ communityName: 'Community' }}
      />,
    );

    const usernameInput = getByPlaceholderText('johndoe');
    expect(usernameInput.type).toBe('text');
  });

  it('should render TextArea with description text', () => {
    const { getByText } = render(
      <ProfileForm
        prev={jest.fn()}
        next={jest.fn()}
        slidesCount={3}
        currentSlideIndex={1}
        communityConfig={{ communityName: 'Community' }}
      />,
    );

    const bioDescription = getByText('Bio');
    expect(bioDescription).toBeInTheDocument();
  });

  it('should show the correct name and username', () => {
    const { queryByText } = renderProfileForm();

    expect(queryByText('username')).toBeDefined();
    expect(queryByText('firstname lastname')).toExist();
  });

  it('should show the correct profile picture', () => {
    const { getByAltText } = renderProfileForm();
    const img = getByAltText('profile');
    expect(img).toHaveAttribute('src');
    expect(img.getAttribute('src')).toEqual('mock_url_link');
  });

  it('should render the correct group headings', async () => {
    const { findByText } = renderProfileForm();

    const heading1 = await findByText('Education');
    const heading2 = await findByText('Name');

    expect(heading1).toBeInTheDocument();
    expect(heading2).toBeInTheDocument();
  });

  it('should render the correct fields', async () => {
    const { findByLabelText } = renderProfileForm();

    const field1 = await findByLabelText(/Education/i);
    const field2 = await findByLabelText(/^Name/i);
    const field3 = await findByLabelText(/Website URL/i);
    const field4 = await findByLabelText(/Username/i);

    expect(field1).toBeInTheDocument();
    expect(field2).toBeInTheDocument();
    expect(field2.getAttribute('placeholder')).toEqual('John Doe');
    expect(field3).toBeInTheDocument();
    expect(field3.getAttribute('placeholder')).toEqual('https://yoursite.com');
    expect(field4).toBeInTheDocument();
    expect(field4.getAttribute('value')).toEqual('username');
  });

  it('should render a stepper', () => {
    const { queryByTestId } = renderProfileForm();

    expect(queryByTestId('stepper')).toExist();
  });

  it('should show the back button', () => {
    const { queryByTestId } = renderProfileForm();

    expect(queryByTestId('back-button')).toExist();
  });

  it('should not be skippable', async () => {
    const { getByText } = renderProfileForm();

    expect(getByText(/continue/i)).toBeInTheDocument();
  });

  it('should render an error message if the request failed', async () => {
    const { getByRole, findByText } = render(
      <ProfileForm
        prev={jest.fn()}
        next={jest.fn()}
        slidesCount={3}
        currentSlideIndex={1}
        communityConfig={{ communityName: 'Community' }}
      />,
    );
    fetch.mockResponse(async () => {
      const body = JSON.stringify({ errors: 'Fake Error' });
      return new Response(body, { status: 422 });
    });

    const submitButton = getByRole('button', { name: 'Continue' });
    submitButton.click();

    const errorMessage = await findByText('An error occurred: Fake Error');
    expect(errorMessage).toBeInTheDocument();
  });
});
