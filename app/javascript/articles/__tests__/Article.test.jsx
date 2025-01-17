/* eslint-disable no-irregular-whitespace */
import { h } from 'preact';
import { render } from '@testing-library/preact';
import { axe } from 'jest-axe';
import '@testing-library/jest-dom';
import { Article } from '..';
import { reactionImagesSupport } from '../../__support__/reaction_images';
import { locale } from '../../utilities/locale';
import {
  article,
  articleWithOrganization,
  articleWithSnippetResult,
  articleWithReactions,
  videoArticle,
  articleWithComments,
  articleWithCommentWithLongParagraph,
  podcastArticle,
  podcastEpisodeArticle,
  userArticle,
  assetPath,
} from './utilities/articleUtilities';
import '../../../assets/javascripts/lib/xss';
import '../../../assets/javascripts/utilities/timeAgo';

const commonProps = {
  commentsIcon: assetPath('comments-bubble.png'),
  videoIcon: assetPath('video-camera.svg'),
};

describe('<Article /> component', () => {
  beforeAll(() => {
    reactionImagesSupport();
  });

  it('should have no a11y violations for a standard article', async () => {
    const { container } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={article}
        currentTag="javascript"
      />,
    );
    const results = await axe(container);

    expect(results).toHaveNoViolations();
  });

  it('should have no a11y violations for a featured article', async () => {
    const { container } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        isFeatured
        article={article}
        currentTag="javascript"
      />,
    );
    const results = await axe(container);

    expect(results).toHaveNoViolations();
  });

  it('should render a standard article', () => {
    const { container, queryByAltText } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={article}
        currentTag="javascript"
      />,
    );

    expect(container.firstChild).not.toHaveClass('crayons-story--featured', {
      exact: false,
    });
    expect(queryByAltText('Emil99 profile')).toExist();
  });

  it('should render a featured article', () => {
    const { container, queryByAltText } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        isFeatured
        article={article}
        currentTag="javascript"
      />,
    );

    expect(container.firstChild).toHaveClass('crayons-story--featured', {
      exact: false,
    });
    expect(queryByAltText('Emil99 profile')).toExist();
  });

  it('should render a rich feed', () => {
    const tree = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        isFeatured
        feedStyle="rich"
        article={article}
        currentTag="javascript"
      />,
    );
    expect(tree).toMatchSnapshot();
  });

  it('should render a featured article for an organization', () => {
    const { container, queryByAltText } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        isFeatured
        article={articleWithOrganization}
        currentTag="javascript"
      />,
    );

    expect(container.firstChild).toHaveClass('crayons-story--featured', {
      exact: false,
    });
    expect(queryByAltText('Web info-mediaries logo')).toExist();
    expect(queryByAltText('Emil99 profile')).toExist();
  });

  it('should render a featured article for a video post', () => {
    const { queryByTitle } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        isFeatured
        article={videoArticle}
        currentTag="javascript"
      />,
    );

    expect(queryByTitle(/video duration/i)).toExist();
  });

  it('should render with an organization', () => {
    const { queryByAltText } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={articleWithOrganization}
        currentTag="javascript"
      />,
    );

    expect(queryByAltText('Web info-mediaries logo')).toExist();
    expect(queryByAltText('Emil99 profile')).toExist();
  });

  it('should render with a flare tag', () => {
    const { queryByText } = render(
      <Article {...commonProps} isBookmarked={false} article={article} />,
    );

    expect(queryByText('#javascript', { selector: 'span' })).toBeDefined();
  });

  it('should render with a snippet result', () => {
    const { queryByText } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={articleWithSnippetResult}
      />,
    );

    expect(
      queryByText(
        '…copying Rest withdrawal Handcrafted multi-state Pre-emptive e-markets feed...overriding RSS Fantastic Plastic Gloves invoice productize systemic Monaco…',
      ),
    ).toExist();
  });

  it('should render with reactions', () => {
    const { getByTitle } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={articleWithReactions}
      />,
    );

    const reactions = getByTitle('Number of reactions');

    expect(reactions.textContent).toEqual(`232 ${locale('core.reaction')}s`);
  });

  it('should render with comments', () => {
    const { getByTitle } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={articleWithComments}
      />,
    );

    const comments = getByTitle('Number of comments');

    expect(comments.textContent).toEqual(`213 ${locale('core.comment')}s`);
  });

  it('should render second paragraph, but not third', () => {
    const { queryByTestId } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={articleWithComments}
      />,
    );

    const comments = queryByTestId('comment-content');

    expect(comments.textContent).toContain('Kitsch hoodie artisan');
    expect(comments.classList).not.toContain('Third paragraph');
  });

  it('should render the first part of a long paragraph', () => {
    const { queryByTestId } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={articleWithCommentWithLongParagraph}
      />,
    );

    const comments = queryByTestId('comment-content');

    expect(comments.textContent).toContain('Start of paragraph');
    expect(comments.classList).not.toContain('End of paragraph');
  });

  it('should render with an add comment button when there are no comments', () => {
    const { queryByTestId } = render(
      <Article {...commonProps} isBookmarked={false} article={article} />,
    );

    expect(queryByTestId('add-a-comment')).toExist();
  });

  it('should render as saved on reading list', () => {
    const { queryByText } = render(
      <Article {...commonProps} isBookmarked article={articleWithComments} />,
    );

    expect(queryByText('Saved', { selector: 'button' })).toBeDefined();
  });

  it('should render as not saved on reading list', () => {
    const { queryByText } = render(
      <Article {...commonProps} isBookmarked={false} article={article} />,
    );

    expect(queryByText('Save', { selector: 'button' })).toBeDefined();
  });

  it('should render a video article', () => {
    const { queryByTitle } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={videoArticle}
        currentTag="javascript"
      />,
    );

    expect(queryByTitle(/video duration/i)).toExist();
  });

  it('should render a podcast article', () => {
    const { queryByAltText, queryByText } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={podcastArticle}
      />,
    );

    expect(queryByAltText('Rubber local')).toExist();
    expect(queryByText('podcast', { selector: 'span' })).toExist();
  });

  it('should render a podcast episode', () => {
    const { queryByText } = render(
      <Article isBookmarked={false} article={podcastEpisodeArticle} />,
    );

    expect(queryByText('podcast', { selector: 'span' })).toExist();
  });

  it('should render a user article', () => {
    const { queryByText } = render(<Article article={userArticle} />);

    expect(queryByText('person', { selector: 'span' })).toExist();
  });

  it('should show bookmark button when article is saveable (default)', () => {
    const { queryByTestId } = render(
      <Article {...commonProps} isBookmarked={false} article={article} />,
    );

    expect(queryByTestId(`article-save-button-${article.id}`)).toBeDefined();
  });

  it('should hide bookmark button when article is not saveable', () => {
    const { queryByTestId } = render(
      <Article
        {...commonProps}
        isBookmarked={false}
        article={article}
        saveable={false}
      />,
    );

    expect(queryByTestId(`article-save-button-${article.id}`)).toBeNull();
  });
});
